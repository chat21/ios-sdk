//
//  ChatGroupsHandler.m
//  Smart21
//
//  Created by Andrea Sponziello on 02/05/15.
//
//

#import "ChatGroupsHandler.h"
//#import "SHPFirebaseTokenDC.h"
//#import "SHPUser.h"
#import "ChatUtil.h"
#import <Firebase/Firebase.h>
#import "ChatGroup.h"
#import "ChatGroupsDB.h"
#import "ChatManager.h"
#import "ChatUser.h"
#import "ChatGroupsSubscriber.h"

@implementation ChatGroupsHandler

-(id)initWithTenant:(NSString *)tenant user:(ChatUser *)user {
    if (self = [super init]) {
//        self.firebaseRef = firebaseRef;
        self.rootRef = [[FIRDatabase database] reference];
        self.tenant = tenant;
        self.loggeduser = user;
        self.me = user.userId;
        self.groups = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(void)addSubscriber:(id<ChatGroupsSubscriber>)subscriber {
    if (!self.subscribers) {
        self.subscribers = [[NSMutableArray alloc] init];
    }
    [self.subscribers addObject:subscriber];
}

-(void)removeSubscriber:(id<ChatGroupsSubscriber>)subscriber {
    if (!self.subscribers) {
        return;
    }
    [self.subscribers removeObject:subscriber];
}

-(void)notifySubscribers:(ChatGroup *)group {
    [ChatManager logDebug:@"ChatGropusHandler: This group was added or changed: %@. Notifying to subscribers...", group.name];
    for (id<ChatGroupsSubscriber> subscriber in self.subscribers) {
        [subscriber groupAddedOrChanged:group];
    }
}

-(void)dispose{
    [self.groupsRef removeAllObservers];
}

-(void)connect {
    FIRDatabaseReference *rootRef = [[FIRDatabase database] reference];
    NSString *groups_path = [ChatUtil groupsPath];
    self.groupsRef = [rootRef child:groups_path];
    
    self.groups_ref_handle_added = [self.groupsRef observeEventType:FIRDataEventTypeChildAdded withBlock:^(FIRDataSnapshot *snapshot) {
        [ChatManager logDebug:@"NEW GROUP: %@", snapshot.value[@"name"]];
        ChatGroup *group = [ChatManager groupFromSnapshotFactory:snapshot];
        [self insertOrUpdateGroup:group completion:^{
            // nothing
        }];
    } withCancelBlock:^(NSError *error) {
        [ChatManager logError:@"%@", error.description];
    }];
    
    self.groups_ref_handle_changed =
    [self.groupsRef observeEventType:FIRDataEventTypeChildChanged withBlock:^(FIRDataSnapshot *snapshot) {
        [ChatManager logDebug:@"UPDATED GROUP: %@", snapshot.value[@"name"]];
        ChatGroup *group = [ChatManager groupFromSnapshotFactory:snapshot];
        [self insertOrUpdateGroup:group completion:^{
            // nothing
        }];
    } withCancelBlock:^(NSError *error) {
        [ChatManager logError:@"%@", error.description];
    }];
}

-(void)insertInMemory:(ChatGroup *)group {
    if (group && group.groupId) {
        [self.groups setObject:group forKey:group.groupId];
    }
    else {
        [ChatManager logError:@"ERROR: CAN'T INSERT A GROUP WITH NIL ID"];
    }
}

//-(void)printAllGroupsInMemory {
//    for (id k in self.groups) {
//        ChatGroup *g = self.groups[k];
//        NSLog(@"group id: %@, name: %@, members: %@", g.groupId, g.name, [ChatGroup membersDictionary2String:g.members]);
//    }
//}

-(ChatGroup *)groupById:(NSString *)groupId {
    return self.groups[groupId];
}

-(void)insertOrUpdateGroup:(ChatGroup *)group completion:(void(^)()) callback {
    [ChatManager logDebug:@"INSERTING OR UPDATING GROUP WITH NAME: %@", group.name];
    group.user = self.me;
    [self insertInMemory:group];
    __block ChatGroup *_group = group;
    [[ChatGroupsDB getSharedInstance] insertOrUpdateGroupSyncronized:_group completion:^{
        [self notifySubscribers:_group];
        _group = nil;
        callback();
    }];
}

-(void)restoreGroupsFromDB {
    NSArray *groups_array = [[ChatGroupsDB getSharedInstance] getAllGroupsForUser:self.me];
    if (!self.groups) {
        self.groups = [[NSMutableDictionary alloc] init];
    }
    for (ChatGroup *g in groups_array) {
        [self.groups setValue:g forKey:g.groupId];
    }
}

@end
