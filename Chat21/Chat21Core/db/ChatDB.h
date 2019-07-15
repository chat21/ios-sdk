//
//  ChatDB.h
//  Soleto
//
//  Created by Andrea Sponziello on 05/12/14.
//
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@class ChatMessage;
@class ChatConversation;
@class ChatGroup;
//@class ChatUser;

@interface ChatDB : NSObject
{
    NSString *databasePath;
}

@property (assign, nonatomic) BOOL logQuery;

+(ChatDB*)getSharedInstance;
//-(BOOL)createDB;
-(BOOL)createDBWithName:(NSString *)name;

// messages

-(void)updateMessageSynchronized:(NSString *)messageId withStatus:(int)status completion:(void(^)(void)) callback;
-(BOOL)updateMessage:(NSString *)messageId status:(int)status text:(NSString *)text snapshotAsJSONString:(NSString *)snapshotAsJSONString;
-(void)removeAllMessagesForConversationSynchronized:(NSString *)conversationId completion:(void(^)(void)) callback;
-(void)insertMessageIfNotExistsSyncronized:(ChatMessage *)message completion:(void(^)(void)) callback;
-(void)getMessageByIdSyncronized:(NSString *)messageId completion:(void(^)(ChatMessage *)) callback;
-(void)getAllMessagesForConversationSyncronized:(NSString *)conversationId start:(int)start count:(int)count completion:(void(^)(NSArray *messages)) callback;

// conversations

-(void)insertOrUpdateConversationSyncronized:(ChatConversation *)conversation completion:(void(^)(void)) callback;
- (void)removeConversationSynchronized:(NSString *)conversationId completion:(void(^)(void)) callback;
- (void)getConversationByIdSynchronized:(NSString *)conversationId completion:(void(^)(ChatConversation *)) callback;
// NO SYNCH
- (NSArray*)getAllConversationsForUser:(NSString *)user archived:(BOOL)archived limit:(int)limit;

@end
