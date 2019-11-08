//
//  ChatConversationsHandler.m
//  Soleto
//
//  Created by Andrea Sponziello on 29/12/14.
//
//

#import "ChatConversationsHandler.h"
#import "ChatUtil.h"
#import "ChatConversation.h"
#import "ChatDB.h"
#import "ChatManager.h"
#import "ChatUser.h"
#import <libkern/OSAtomic.h>
#import "FirebaseDatabase/FIRDatabase.h"

@interface ChatConversationsHandler () {
    dispatch_queue_t serialConversationsMemoryQueue;
}
@end

@implementation ChatConversationsHandler

-(id)initWithTenant:(NSString *)tenant user:(ChatUser *)user {
    if (self = [super init]) {
//        self.lastEventHandler = 1;
        //        self.firebaseRef = firebaseRef;
        serialConversationsMemoryQueue = dispatch_queue_create("conversationsQueue", DISPATCH_QUEUE_SERIAL);
        self.rootRef = [[FIRDatabase database] reference];
        self.tenant = tenant;
        self.loggeduser = user;
        self.me = user.userId;
        self.conversations = [[NSMutableArray alloc] init];
        self.archivedConversations = [[NSMutableArray alloc] init];
    }
    return self;
}

-(void)dispose {
    [self.conversationsRef removeAllObservers];
    [self.archivedConversationsRef removeAllObservers];
    [self removeAllObservers];
    self.conversations_ref_handle_added = 0;
    self.conversations_ref_handle_changed = 0;
    self.conversations_ref_handle_removed = 0;
}

-(void)restoreConversationsFromDB {
    self.conversations = [[[ChatDB getSharedInstance] getAllConversationsForUser:self.me archived:NO limit:0] mutableCopy];
    self.archivedConversations = [[[ChatDB getSharedInstance] getAllConversationsForUser:self.me archived:YES limit:150] mutableCopy];
}

-(void)connect {
    [self connect_conversations];
    [self connect_archived_conversations];
}

-(void)connect_conversations {
    // if already connected, return.
    if (self.conversations_ref_handle_added) {
        return;
    }
    NSString *conversations_path = [ChatUtil conversationsPathForUserId:self.loggeduser.userId];
    FIRDatabaseReference *rootRef = [[FIRDatabase database] reference];
    self.conversationsRef = [rootRef child: conversations_path];
    [self.conversationsRef keepSynced:YES];
    
    NSInteger lasttime = 0;
    NSMutableArray *conversations = self.conversations;
    if (conversations && conversations.count > 0) {
        ChatConversation *conversation = [conversations firstObject];
        lasttime = conversation.date.timeIntervalSince1970 * 1000; // objc return time in seconds, firebase saves time in milliseconds. queryStartingAtValue: will respond to events at nodes with a value greater than or equal to startValue. So seconds is always < then milliseconds. * 1000 translates seconds in millis and the query is ok.
    } else {
        lasttime = 0;
    }
    //  queryLimitedToLast:20]
    self.conversations_ref_handle_added = [[[self.conversationsRef queryOrderedByChild:@"timestamp"]
                                             queryStartingAtValue:@(lasttime)]
                                             observeEventType:FIRDataEventTypeChildAdded withBlock:^(FIRDataSnapshot *snapshot) {
        [ChatManager logDebug:@"NEW CONVERSATION SNAPSHOT: %@", snapshot];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            if (![self isValidConversationSnapshot:snapshot]) {
                [ChatManager logDebug:@"Invalid conversation snapshot, discarding."];
                return;
            }
            
            ChatConversation *conversation = [ChatConversation conversationFromSnapshotFactory:snapshot me:self.loggeduser];
            ChatManager *chatm = [ChatManager getInstance];
            if (chatm.onCoversationArrived) {
                conversation = chatm.onCoversationArrived(conversation);
                if (conversation == nil) {
                    return;
                }
            }
            
            if ([self.currentOpenConversationId isEqualToString:conversation.conversationId] && conversation.is_new == YES) {
                // changes (forces) the "is_new" flag to FALSE;
                conversation.is_new = NO;
                FIRDatabaseReference *conversation_ref = [self.conversationsRef child:conversation.conversationId];
                [ChatManager logDebug:@"UPDATING IS_NEW=NO FOR CONVERSATION %@", conversation_ref];
                [chatm updateConversationIsNew:conversation_ref is_new:conversation.is_new];
            }
            conversation.archived = NO;
            [self insertOrUpdateConversationOnDB:conversation completion:^{
                [self insertConversationInMemory:conversation completion:^{
                    [self notifyEvent:ChatEventConversationAdded conversation:conversation];
                }];
            }];
        });
    } withCancelBlock:^(NSError *error) {
        [ChatManager logDebug:@"%@", error.description];
    }];
    
    self.conversations_ref_handle_changed = [[self.conversationsRef  queryOrderedByChild:@"timestamp"] observeEventType:FIRDataEventTypeChildChanged withBlock:^(FIRDataSnapshot *snapshot) {
        [ChatManager logDebug:@"CHANGED CONVERSATION SNAPSHOT: %@", snapshot];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            ChatConversation *conversation = [ChatConversation conversationFromSnapshotFactory:snapshot me:self.loggeduser];
            ChatManager *chatm = [ChatManager getInstance];
            if (chatm.onCoversationUpdated) {
                conversation = chatm.onCoversationUpdated(conversation);
                if (conversation == nil) {
                    [ChatManager logDebug:@"Handler returned null Conversation. Stopping pipeline."];
                    return;
                }
            }
            
            if ([self.currentOpenConversationId isEqualToString:conversation.conversationId] && conversation.is_new == YES) {
                // changes (forces) the "is_new" flag to FALSE;
                conversation.is_new = NO;
                FIRDatabaseReference *conversation_ref = [self.conversationsRef child:conversation.conversationId];
                [ChatManager logDebug:@"UPDATING IS_NEW=NO FOR CONVERSATION %@", conversation_ref];
                [chatm updateConversationIsNew:conversation_ref is_new:conversation.is_new];
            }
            conversation.archived = NO;
            
            // searching conversation and his index in memory
            NSDictionary *found_conversation_values = [self findConversationInMemoryById:conversation.conversationId];
            ChatConversation *found_conversation = found_conversation_values[@"conversation"];
            int found_index = ((NSNumber *) found_conversation_values[@"index"]).intValue;
            
            [self insertOrUpdateConversationOnDB:conversation completion:^{
                [self updateConversationInMemory:conversation completion:^{
                    conversation.indexInMemory = found_index;
                    // Next step: create an event object with properties: .conversation, .indexInMemory.
                    // For the moment the conversation will hold his position in memory array.
                    if ([conversation.date isEqualToDate:found_conversation.date]) {
                        [self notifyEvent:ChatEventConversationReadStatusChanged conversation:conversation];
                    }
                    else {
                        [self notifyEvent:ChatEventConversationChanged conversation:conversation];
                    }
                }];
            }];
        });
    } withCancelBlock:^(NSError *error) {
        [ChatManager logDebug:@"%@", error.description];
    }];
    
    self.conversations_ref_handle_removed =
    [self.conversationsRef observeEventType:FIRDataEventTypeChildRemoved withBlock:^(FIRDataSnapshot *snapshot) {
        [ChatManager logDebug:@"REMOVED CONVERSATION SNAPSHOT: %@", snapshot];
        ChatConversation *conversation = [ChatConversation conversationFromSnapshotFactory:snapshot me:self.loggeduser];
        [self removeConversationOnDB:conversation completion:^{
            [self removeConversationInMemory:conversation completion:^{
                [self notifyEvent:ChatEventConversationDeleted conversation:conversation];
            }];
        }];
    } withCancelBlock:^(NSError *error) {
        [ChatManager logDebug:@"%@", error.description];
    }];
}

-(NSDictionary *)findConversationInMemoryById:(NSString *)conversationId {
    for (int i = 0; i < self.conversations.count; i++) {
        if ([self.conversations[i].conversationId isEqualToString:conversationId]) {
            
            return @{
                     @"conversation": self.conversations[i],
                     @"index": @(i)
                    };
        }
    }
    return nil;
}

-(void)connect_archived_conversations {
    // if already connected, return.
    if (self.archived_conversations_ref_handle_added) { //conversations_ref_handle_added) {
        return;
    }
    NSString *archived_conversations_path = [ChatUtil archivedConversationsPathForUserId:self.loggeduser.userId];
    FIRDatabaseReference *rootRef = [[FIRDatabase database] reference];
    self.archivedConversationsRef = [rootRef child: archived_conversations_path];
    [self.archivedConversationsRef keepSynced:YES];

    NSInteger lasttime = 0;
    NSMutableArray *conversations = self.archivedConversations;
    if (conversations && conversations.count > 0) {
        ChatConversation *conversation = [conversations firstObject];
        lasttime = conversation.date.timeIntervalSince1970 * 1000; // objc return time in seconds, firebase saves time in milliseconds. queryStartingAtValue: will respond to events at nodes with a value greater than or equal to startValue. So seconds is always < then milliseconds. * 1000 translates seconds in millis and the query is ok.
    } else {
        lasttime = 0;
    }
    
    self.archived_conversations_ref_handle_added = [[[self.archivedConversationsRef queryOrderedByChild:@"timestamp"] queryStartingAtValue:@(lasttime)] observeEventType:FIRDataEventTypeChildAdded withBlock:^(FIRDataSnapshot *snapshot) {
        [ChatManager logDebug:@"NEW ARCHIVED CONVERSATION SNAPSHOT: %@", snapshot];
        if (![self isValidConversationSnapshot:snapshot]) {
            [ChatManager logDebug:@"Invalid conversation snapshot, discarding."];
            return;
        }
        ChatConversation *conversation = [ChatConversation conversationFromSnapshotFactory:snapshot me:self.loggeduser];
//        if (conversation.status == CONV_STATUS_FAILED) {
//            // a remote conversation can't be in failed status. force to last_message status
//            // if the sender WRONGLY set the conversation STATUS to 0 this will block the access to the conversation.
//            // IN FUTURE SERVER-SIDE HANDLING OF MESSAGE SENDING, WILL BE THE SERVER-SIDE SCRIPT RESPONSIBLE OF SETTING THE CONV STATUS AND THIS VERIFICATION CAN BE REMOVED.
//            conversation.status = CONV_STATUS_LAST_MESSAGE;
//        }
        conversation.archived = YES;
        [self insertOrUpdateConversationOnDB:conversation completion:^{
            [self insertArchivedConversationInMemory:conversation completion:^{
                [self notifyEvent:ChatEventArchivedConversationAdded conversation:conversation];
            }];
        }];
    } withCancelBlock:^(NSError *error) {
        [ChatManager logDebug:@"%@", error.description];
    }];

    self.archived_conversations_ref_handle_removed =
    [self.archivedConversationsRef observeEventType:FIRDataEventTypeChildRemoved withBlock:^(FIRDataSnapshot *snapshot) {
        [ChatManager logDebug:@"REMOVED ARCHIVED CONVERSATION SNAPSHOT: %@", snapshot];
        ChatConversation *conversation = [ChatConversation conversationFromSnapshotFactory:snapshot me:self.loggeduser];
        [self unarchiveConversation:conversation completion:^{
            [self notifyEvent:ChatEventArchivedConversationRemoved conversation:conversation];
        }];
    } withCancelBlock:^(NSError *error) {
        [ChatManager logDebug:@"%@", error.description];
    }];
}

-(BOOL)isValidConversationSnapshot:(FIRDataSnapshot *)snapshot {
    if (snapshot.value[CONV_RECIPIENT_KEY] == nil) {
        [ChatManager logDebug:@"CONV:RECIPIENT is mandatory. Discarding message."];
        return NO;
    }
    else if (snapshot.value[CONV_LAST_MESSAGE_TEXT_KEY] == nil) {
        [ChatManager logDebug:@"CONV:TEXT is mandatory. Discarding message."];
        return NO;
    }
    else if (snapshot.value[CONV_SENDER_KEY] == nil) {
        [ChatManager logDebug:@"CONV:SENDER is mandatory. Discarding message."];
        return NO;
    }
    else if (snapshot.value[CONV_TIMESTAMP_KEY] == nil) {
        [ChatManager logDebug:@"MSG:TIMESTAMP is mandatory. Discarding message."];
        return NO;
    }
    else if (snapshot.value[CONV_STATUS_KEY] == nil) {
        [ChatManager logDebug:@"MSG:TIMESTAMP is mandatory. Discarding message."];
        return NO;
    }
    return YES;
}

// MEMORY DB - CONVERSATIONS

-(void)insertConversationInMemory:(ChatConversation *)conversation completion:(void(^)(void))callback {
    dispatch_async(serialConversationsMemoryQueue, ^{
        [self insertConversationInMemory:conversation fromConversations:self.conversations];
        if (callback != nil) callback();
    });
}

-(void)updateConversationInMemory:(ChatConversation *)conversation completion:(void(^)(void))callback {
    dispatch_async(serialConversationsMemoryQueue, ^{
        [self updateConversationInMemory:conversation fromConversations:self.conversations];
        if (callback != nil) callback();
    });
}

-(void)removeConversationInMemory:(ChatConversation *)conversation completion:(void(^)(void))callback {
    dispatch_async(serialConversationsMemoryQueue, ^{
        [self removeConversationInMemory:conversation fromConversations:self.conversations];
        if (callback != nil) callback();
    });
}

// MEMORY DB - ARCHIVED-CONVERSATIONS

-(void)insertArchivedConversationInMemory:(ChatConversation *)conversation completion:(void(^)(void))callback {
    dispatch_async(serialConversationsMemoryQueue, ^{
        [self insertConversationInMemory:conversation fromConversations:self.archivedConversations];
        if (callback != nil) callback();
    });
}

-(void)updateArchivedConversationInMemory:(ChatConversation *)conversation completion:(void(^)(void))callback {
    dispatch_async(serialConversationsMemoryQueue, ^{
        [self updateConversationInMemory:conversation fromConversations:self.archivedConversations];
        if (callback != nil) callback();
    });
}

-(void)removeArchivedConversationInMemory:(ChatConversation *)conversation completion:(void(^)(void))callback {
    dispatch_async(serialConversationsMemoryQueue, ^{
        [self removeConversationInMemory:conversation fromConversations:self.archivedConversations];
        if (callback != nil) callback();
    });
}

// MEMORY DB

-(void)insertConversationInMemory:(ChatConversation *)conversation fromConversations:(NSMutableArray<ChatConversation *> *)conversations {
    for (int i = 0; i < conversations.count; i++) {
        ChatConversation *conv = conversations[i];
        if([conv.conversationId isEqualToString: conversation.conversationId]) {
            [ChatManager logDebug:@"conv found, updating"];
            [conversations removeObjectAtIndex:i]; // remove conversation...
            [conversations insertObject:conversation atIndex:0]; // ...then put it on top
            return;
        }
    }
    [conversations insertObject:conversation atIndex:0];
}

-(void)updateConversationInMemory:(ChatConversation *)conversation fromConversations:(NSMutableArray<ChatConversation *> *)conversations {
    for (int i = 0; i < conversations.count; i++) {
        ChatConversation *conv = conversations[i];
        if([conv.conversationId isEqualToString: conversation.conversationId]) {
            if ([conv.date isEqualToDate:conversation.date]) {
                conversations[i] = conversation; // replace conversation in the same position
                return;
            }
            else {
                [conversations removeObjectAtIndex:i]; // remove conversation...
                [conversations insertObject:conversation atIndex:0]; // ...then put it on top
                return;
            }
        }
    }
}

-(int)removeConversationInMemory:(ChatConversation *)conversation fromConversations:(NSMutableArray<ChatConversation *> *)conversations {
    for (int i = 0; i < conversations.count; i++) {
        ChatConversation *conv = conversations[i];
        if([conv.conversationId isEqualToString: conversation.conversationId]) {
            [conversations removeObjectAtIndex:i];
            return i;
        }
    }
    return -1;
}

-(void)updateLocalConversation:(ChatConversation *)conversation completion:(void(^)(void)) callback {
    [self insertOrUpdateConversationOnDB:conversation completion:^{
        [self updateConversationInMemory:conversation completion:^{
            if (callback != nil) callback();
        }];
    }];
}

-(void)removeLocalConversation:(ChatConversation *)conversation completion:(void(^)(void)) callback {
    [self removeConversationOnDB:conversation completion:^{
        [self removeConversationInMemory:conversation completion:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (callback != nil) callback();
            });
        }];
    }];
}

-(void)insertOrUpdateConversationOnDB:(ChatConversation *)conversation completion:(void(^)(void)) callback {
    __weak NSString *_me = self.me;
    conversation.user = _me;
    __weak ChatConversation *_conv = conversation;
    [[ChatDB getSharedInstance] insertOrUpdateConversationSyncronized:_conv completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (callback != nil) callback();
        });
    }];
    conversation = nil;
    _conv = nil;
}

-(void)removeConversationOnDB:(ChatConversation *)conversation completion:(void(^)(void)) callback {
    conversation.user = self.me;
    [[ChatDB getSharedInstance] removeConversationSynchronized:conversation.conversationId completion:^{
        if (callback != nil) callback();
    }];
}

-(void)unarchiveConversation:(ChatConversation *)conversation completion:(void(^)(void)) callback {
    [self removeArchivedConversationInMemory:conversation completion:^{
        conversation.archived = NO;
        [[ChatDB getSharedInstance] insertOrUpdateConversationSyncronized:conversation completion:^{
            if (callback != nil) callback();
        }];
    }];
}

-(void)removeArchivedConversationOnDB:(ChatConversation *)conversation {
    conversation.user = self.me;
    [[ChatDB getSharedInstance] removeConversationSynchronized:conversation.conversationId completion:^{
        // if (callback != nil) callback();
    }];
}

// observer

-(void)notifyEvent:(ChatConversationEventType)event conversation:(ChatConversation *)conversation {
    if (!self.eventObservers) {
        return;
    }
    NSMutableDictionary *eventCallbacks = [self.eventObservers objectForKey:@(event)];
    if (!eventCallbacks) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSNumber *event_handle_key in eventCallbacks.allKeys) {
            void (^callback)(ChatConversation *conversation) = [eventCallbacks objectForKey:event_handle_key];
            callback(conversation);
        }
    });
}

// v2

-(NSUInteger)observeEvent:(ChatConversationEventType)eventType withCallback:(void (^)(ChatConversation *conversation))callback {
    if (!self.eventObservers) {
        self.eventObservers = [[NSMutableDictionary alloc] init];
    }
    NSMutableDictionary *eventCallbacks = [self.eventObservers objectForKey:@(eventType)];
    if (!eventCallbacks) {
        eventCallbacks = [[NSMutableDictionary alloc] init];
        [self.eventObservers setObject:eventCallbacks forKey:@(eventType)];
    }
    NSUInteger callback_handle = (NSUInteger) OSAtomicIncrement64Barrier(&_lastEventHandler);
    [eventCallbacks setObject:callback forKey:@(callback_handle)];
    return callback_handle;
}

-(void)removeObserverWithHandle:(NSUInteger)event_handler {
    if (!self.eventObservers) {
        return;
    }
    
    //    // test
    //    for (NSNumber *event_key in self.eventObservers) {
    //        NSMutableDictionary *eventCallbacks = [self.eventObservers objectForKey:event_key];
    //        NSLog(@"Removing callback for event %@. Callback: %@",event_key, [eventCallbacks objectForKey:@(event_handler)]);
    //    }
    
    // iterate all keys (events)
    for (NSNumber *event_key in self.eventObservers) {
        NSMutableDictionary *eventCallbacks = [self.eventObservers objectForKey:event_key];
        [eventCallbacks removeObjectForKey:@(event_handler)];
    }
    
    //    for (NSNumber *event_key in self.eventObservers) {
    //        NSMutableDictionary *eventCallbacks = [self.eventObservers objectForKey:event_key];
    //        NSLog(@"After removed callback for event %@. Callback: %@",event_key, [eventCallbacks objectForKey:@(event_handler)]);
    //    }
}

-(void)removeAllObservers {
    if (!self.eventObservers) {
        return;
    }
    
    // iterate all keys (events)
    for (NSNumber *event_key in self.eventObservers) {
        NSMutableDictionary *eventCallbacks = [self.eventObservers objectForKey:event_key];
        [eventCallbacks removeAllObjects];
    }
}

@end
