//
//  ChatContactsSynchronizer.m
//  chat21
//
//  Created by Andrea Sponziello on 09/09/2017.
//  Copyright © 2017 Frontiere21. All rights reserved.
//

#import "ChatContactsSynchronizer.h"
#import "ChatUser.h"
#import "ChatUtil.h"
#import "ChatManager.h"
#import "ChatContactsDB.h"
#import "FirebaseDatabase/FIRDatabaseReference.h"
#import "ChatDiskImageCache.h"
#import "CellConfigurator.h"
#import "ChatImageUtil.h"

@interface ChatContactsSynchronizer () {
}
@end

@implementation ChatContactsSynchronizer

-(id)initWithTenant:(NSString *)tenant user:(ChatUser *)user {
    if (self = [super init]) {
        self.rootRef = [[FIRDatabase database] reference];
        self.tenant = tenant;
        self.loggeduser = user;
    }
    return self;
}

-(void)addSynchSubscriber:(id<ChatSynchDelegate>)subscriber {
    if (!self.synchSubscribers) {
        self.synchSubscribers = [[NSMutableArray alloc] init];
    }
    [self.synchSubscribers addObject:subscriber];
}

-(void)removeSynchSubscriber:(id<ChatSynchDelegate>)subscriber {
    if (!self.synchSubscribers) {
        return;
    }
    [self.synchSubscribers removeObject:subscriber];
}

-(void)checkDownloadImageChanged:(ChatUser *)oldContact newContact:(ChatUser *)newContact {
    if (newContact.imageChangedAt > oldContact.imageChangedAt) {
        NSString *imageURL = [ChatManager profileImageURLOf:newContact.userId];
        ChatDiskImageCache *imageCache = [ChatManager getInstance].imageCache;
        [imageCache removeCachedImagesOfProfile:oldContact.userId];
        [imageCache getImage:imageURL completionHandler:^(NSString *imageURL, UIImage *image) {
            [imageCache createThumbsInCacheForProfileId:newContact.userId originalImage:image];
            [self notifyImageChanged:newContact];
        }];
    }
}

-(void)notifySynchEnd {
    for (id<ChatSynchDelegate> subscriber in self.synchSubscribers) {
        [subscriber synchEnd];
    }
}

-(void)notifyContactUpdated:(ChatUser *)oldContact newContact:(ChatUser *)newContact {
    for (id<ChatSynchDelegate> subscriber in self.synchSubscribers) {
        [subscriber contactUpdated:oldContact newContact:newContact];
    }
}

-(void)notifyImageChanged:(ChatUser *)contact {
    for (id<ChatSynchDelegate> subscriber in self.synchSubscribers) {
        [subscriber contactImageChanged:contact];
    }
}

-(void)startSynchro {
    if (![self getFirstSynchroOver]) {
        self.synchronizing = YES;
    }
    else {
        self.synchronizing = NO;
    }
    [self synchContacts];
}

-(void)synchContacts {
    [ChatManager logDebug:@"Remote contacts synch start."];
    FIRDatabaseReference *rootRef = [[FIRDatabase database] reference];
    self.contactsRef = [rootRef child: [ChatUtil contactsPath]];
    [self.contactsRef keepSynced:YES];
    
    [self lastQueryTimeWithCompletion:^(long lasttime) {
        if (!self.contact_ref_handle_added) {
            self.contact_ref_handle_added = [[[self.contactsRef queryOrderedByChild:@"timestamp"] queryStartingAtValue:@(lasttime)] observeEventType:FIRDataEventTypeChildAdded withBlock:^(FIRDataSnapshot *snapshot) {
                [ChatManager logDebug:@"FIREBASE: ADDED CONTACT SNAPSHOT: %@", snapshot];
                ChatUser *contact = [ChatContactsSynchronizer contactFromSnapshotFactory:snapshot];
                if (contact && contact.createdon == lasttime) {
                    [ChatManager logDebug:@"SAME CONTACT.TIMESTAMP OF LASTTIME. IGNORING CONTACT %@", contact.fullname];
                }
                else {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                        if (contact) {
                            [[ChatContactsDB getSharedInstance] getContactByIdSyncronized:contact.userId completion:^(ChatUser *oldContact) {
                                [self insertOrUpdateContactOnDB:contact];
                                [self notifyContactUpdated:oldContact newContact:contact];
                                [self checkDownloadImageChanged:oldContact newContact:contact];
                            }];
                        }
                    });
                }
            } withCancelBlock:^(NSError *error) {
                [ChatManager logDebug:@"%@", error.description];
            }];
        }
        
        [self startSynchTimer]; // if ZERO contacts, this timer puts self.synchronizing to FALSE
        
        if (!self.contact_ref_handle_changed) {
            self.contact_ref_handle_changed =
            [[[self.contactsRef queryOrderedByChild:@"timestamp"] queryStartingAtValue:@(lasttime)]observeEventType:FIRDataEventTypeChildChanged withBlock:^(FIRDataSnapshot *snapshot) {
                [ChatManager logDebug:@"FIREBASE: UPDATED CONTACT SNAPSHOT: %@", snapshot];
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                    ChatUser *contact = [ChatContactsSynchronizer contactFromSnapshotFactory:snapshot];
                    [ChatManager logDebug:@"changed contact timestamp: %ld", contact.createdon];
                    if (contact) {
                        [[ChatContactsDB getSharedInstance] getContactByIdSyncronized:contact.userId completion:^(ChatUser *oldContact) {
                            [self insertOrUpdateContactOnDB:contact];
                            [self notifyContactUpdated:oldContact newContact:contact];
                            [self checkDownloadImageChanged:oldContact newContact:contact];
                        }];
                    }
                });
            } withCancelBlock:^(NSError *error) {
                [ChatManager logError:@"%@", error.description];
            }];
        }
        
        if (!self.contact_ref_handle_removed) {
            self.contact_ref_handle_removed =
            [self.contactsRef observeEventType:FIRDataEventTypeChildRemoved withBlock:^(FIRDataSnapshot *snapshot) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                    [ChatManager logDebug:@"FIREBASE: REMOVED CONTACT SNAPSHOT: %@", snapshot];
                    ChatUser *contact = [ChatContactsSynchronizer contactFromSnapshotFactory:snapshot];
                    if (contact) {
                        [self removeContactOnDB:contact];
                    }
                });
            } withCancelBlock:^(NSError *error) {
                [ChatManager logError:@"%@", error.description];
            }];
        }
    }];
}

-(void)startSynchTimer {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.synchronizing = YES;
        [self resetSynchTimer];
        self.synchTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(synchTimerPaused:) userInfo:nil repeats:NO];
   });
}

-(void)synchTimerPaused:(NSTimer *)timer {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setFirstSynchroOver:YES];
        self.synchronizing = NO;
        [self notifySynchEnd];
        [self resetSynchTimer];
    });
}

-(void)resetSynchTimer {
    if (self.synchTimer) {
        if ([self.synchTimer isValid]) {
            [self.synchTimer invalidate];
        }
        self.synchTimer = nil;
    }
}

-(void)lastQueryTimeWithCompletion:(void(^)(long lasttime)) callback {
    [[ChatContactsDB getSharedInstance] getMostRecentContactSyncronizedWithCompletion:^(ChatUser *contact) {
        if (contact) {
            long lasttime = contact.createdon;
            callback(lasttime);
        }
        else {
            callback(0);
        }
    }];
}

static NSString *LAST_CONTACTS_TIMESTAMP_KEY = @"last-contacts-timestamp";
static NSString *FIRST_SYNCHRO_KEY = @"first-contacts-synchro";

-(void)setFirstSynchroOver:(BOOL)isOver {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSString *userId = [ChatManager getInstance].loggedUser.userId;
    NSString *synchroKey = [[NSString alloc] initWithFormat:@"%@-%@",FIRST_SYNCHRO_KEY, userId];
    [userPreferences setBool:isOver forKey:synchroKey];
    [userPreferences synchronize];
}

-(BOOL)getFirstSynchroOver {
    NSString *userId = [ChatManager getInstance].loggedUser.userId;
    NSString *synchroKey = [[NSString alloc] initWithFormat:@"%@-%@",FIRST_SYNCHRO_KEY, userId];
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    BOOL firstSinchro = (BOOL)[userPreferences boolForKey:synchroKey];
    return firstSinchro;
}

-(void)insertOrUpdateContactOnDB:(ChatUser *)user {
    __block ChatUser *_user = user;
    [[ChatContactsDB getSharedInstance] insertOrUpdateContactSyncronized:_user completion:^{
        self.synchronizing ? [ChatManager logDebug:@"SYNCHRONIZING"] : [ChatManager logDebug:@"NO-SYNCHRONIZING"];
        _user = nil;
        [self startSynchTimer];
    }];
}

-(void)removeContactOnDB:(ChatUser *)user {
    [ChatManager logDebug:@"REMOVING CONTACT: %@ (%@ %@)", user.userId, user.firstname, user.lastname];
    [[ChatContactsDB getSharedInstance] removeContactSynchronized:user.userId completion:nil];
}

-(void)dispose {
    [self.contactsRef removeAllObservers];
}

+(ChatUser *)contactFromSnapshotFactory:(FIRDataSnapshot *)snapshot {
    [ChatManager logDebug:@"Snapshot.value is of type: %@", [snapshot.value class]];
    if ([snapshot.value isKindOfClass:[NSDictionary class]]) {
        NSString *userId = snapshot.value[FIREBASE_USER_ID];
        if (!userId) {
            [ChatManager logDebug:@"ERROR. NO UID. INVALID USER."];
            return nil;
        }
        else if (![snapshot.value[FIREBASE_USER_ID] isKindOfClass:[NSString class]]) { // user_id must be a string
            [ChatManager logDebug:@"ERROR. NO UID. INVALID USER."];
            return nil;
        }
        
        NSString *name = snapshot.value[FIREBASE_USER_FIRSTNAME];
        if (!name) {
            name = @"";
        }
        else if ([snapshot.value[FIREBASE_USER_FIRSTNAME] isKindOfClass:[NSString class]]) { // must be a string
            name = snapshot.value[FIREBASE_USER_FIRSTNAME];
        }
        else {
            name = @"";
        }
        
        NSString *lastname = snapshot.value[FIREBASE_USER_LASTNAME];
        if (!lastname) {
            lastname = @"";
        }
        else if ([snapshot.value[FIREBASE_USER_LASTNAME] isKindOfClass:[NSString class]]) { // must be a string
            lastname = snapshot.value[FIREBASE_USER_LASTNAME];
        }
        else {
            lastname = @"";
        }
        
        NSString *email = snapshot.value[FIREBASE_USER_EMAIL];
        if (!email) {
            email = @"";
        }
        else if ([snapshot.value[FIREBASE_USER_EMAIL] isKindOfClass:[NSString class]]) { // must be a string
            email = snapshot.value[FIREBASE_USER_EMAIL];
        }
        else {
            email = @"";
        }
        NSNumber *imagechangedat = snapshot.value[FIREBASE_USER_IMAGE_CHANGED_AT];
        [ChatManager logDebug:@"imagechangedat %@", imagechangedat];
        
        NSNumber *createdon = snapshot.value[FIREBASE_USER_TIMESTAMP];
        
        ChatUser *contact = [[ChatUser alloc] init];
        contact.firstname = name;
        contact.lastname = lastname;
        contact.userId = userId;
        contact.email = email;
        if (imagechangedat) {
            contact.imageChangedAt = [imagechangedat integerValue];// / 1000;
        }
        contact.createdon = [createdon integerValue];// / 1000; // firebase timestamp is in millis
        return contact;
    }
    else {
        [ChatManager logError:@"ERROR! USER (SNAPSHOT.VALUE) IS NOT A DICTIONARY."];
    }
    return nil;
}

+(ChatUser *)contactFromDictionaryFactory:(NSDictionary *)snapshot {
    NSString *userId = userId = snapshot[FIREBASE_USER_ID];
    if (!userId) { // user_id can t be null
        [ChatManager logError:@"ERROR. NO UID. INVALID USER."];
        return nil;
    }
    else if (![snapshot[FIREBASE_USER_ID] isKindOfClass:[NSString class]]) { // user_id must be a string
        [ChatManager logDebug:@"ERROR. NO UID. INVALID USER."];
        return nil;
    }
    
    NSString *name = snapshot[FIREBASE_USER_FIRSTNAME];
    if (!name) {
        name = @"";
    }
    else if ([snapshot[FIREBASE_USER_FIRSTNAME] isKindOfClass:[NSString class]]) { // must be a string
        name = snapshot[FIREBASE_USER_FIRSTNAME];
    }
    else {
        name = @"";
    }
    
    NSString *lastname = snapshot[FIREBASE_USER_LASTNAME];
    if (!lastname) {
        lastname = @"";
    }
    else if ([snapshot[FIREBASE_USER_LASTNAME] isKindOfClass:[NSString class]]) { // must be a string
        lastname = snapshot[FIREBASE_USER_LASTNAME];
    }
    else {
        lastname = @"";
    }
    
    NSString *email = snapshot[FIREBASE_USER_EMAIL];
    if (!email) {
        email = @"";
    }
    else if ([snapshot[FIREBASE_USER_EMAIL] isKindOfClass:[NSString class]]) { // must be a string
        email = snapshot[FIREBASE_USER_EMAIL];
    }
    else {
        email = @"";
    }
        
    NSNumber *imagechangedat = snapshot[FIREBASE_USER_IMAGE_CHANGED_AT];
    [ChatManager logDebug:@"imagechangedat %@", imagechangedat];
    
    NSNumber *createdon = snapshot[FIREBASE_USER_TIMESTAMP];
    
    ChatUser *contact = [[ChatUser alloc] init];
    contact.firstname = name;
    contact.lastname = lastname;
    contact.userId = userId;
    contact.email = email;
    if (imagechangedat) {
        contact.imageChangedAt = [imagechangedat integerValue];
    }
    contact.createdon = [createdon integerValue]; // firebase timestamp is in millis
    return contact;
}

@end
