//
//  ChatManager.h
//  Soleto
//
//  Created by Andrea Sponziello on 20/12/14.
//
//

#import <Foundation/Foundation.h>
#import "FirebaseDatabase/FIRDataSnapshot.h"
#import "FirebaseAuth/FIRAuth.h"
#import "FirebaseStorage/FirebaseStorage.h"

@import UIKit;

@class ChatConversationHandler;
@class ChatConversationsHandler;
@class ChatGroupsHandler;
@class SHPUser;
@class ChatGroup;
@class FDataSnapshot;
@class ChatConversation;
@class ChatPresenceHandler;
@class ChatConversationsVC;
@class ChatUser;
@class ChatContactsSynchronizer;
@class ChatSpeaker;
@class ChatConversationHandler;
@class ChatConnectionStatusHandler;
@class ChatDiskImageCache;
@class ChatMessage;

static int const CHAT_LOG_LEVEL_ERROR = 0;
static int const CHAT_LOG_LEVEL_WARNING = 1;
static int const CHAT_LOG_LEVEL_INFO = 2;
static int const CHAT_LOG_LEVEL_DEBUG = 3;

static NSString *CHAT_DEFAULT_TENANT = @"chat";

// CONFIG KEYS
static NSString *CHAT_CONFIG_KEY_TENANT = @"tenant";
static NSString *CHAT_CONFIG_KEY_GROUPS_MODE = @"groups-mode";
static NSString *CHAT_CONFIG_KEY_SYNCHRONIZE_CONTACTS = @"synchronize-contacts";
static NSString *CHAT_CONFIG_KEY_CONVERSATIONS_TABBAR_INDEX = @"conversations-tabbar-index";
static NSString *CHAT_CONFIG_KEY_SHOW_WRITE_TO = @"show-write-to";
static NSString *CHAT_CONFIG_KEY_SHOW_ARCHIVED = @"show-archived";
static NSString *CHAT_CONFIG_KEY_LOG_LEVEL = @"log-level";

@interface ChatManager : NSObject

// services' plist properties
@property (nonatomic, strong) NSString *baseURL;
@property (nonatomic, strong) NSString *archiveConversationURI;
@property (nonatomic, strong) NSString *archiveAndCloseSupportConversationURI;
@property (nonatomic, strong) NSString *profileImageBaseURL;
@property (nonatomic, strong) NSString *deleteProfilePhotoURI;

@property (nonatomic, strong) ChatUser *loggedUser;
@property (nonatomic, strong) NSMutableDictionary<NSString*, ChatConversationHandler*> *handlers;
@property (nonatomic, strong) ChatConversationsHandler *conversationsHandler;
@property (nonatomic, strong) ChatPresenceHandler *presenceHandler;
@property (nonatomic, strong) ChatConnectionStatusHandler *connectionStatusHandler;
@property (nonatomic, strong) ChatGroupsHandler *groupsHandler;
@property (nonatomic, strong) ChatContactsSynchronizer *contactsSynchronizer;
@property (nonatomic, strong) ChatDiskImageCache *imageCache;
@property (strong, nonatomic) FIRAuthStateDidChangeListenerHandle authStateDidChangeListenerHandle;

// CONFIG
@property (nonatomic, strong) NSString *tenant;
@property (assign, nonatomic) NSInteger tabBarIndex;
@property (assign, nonatomic) BOOL groupsMode;
@property (assign, nonatomic) BOOL synchronizeContacts;
@property (assign, nonatomic) BOOL showWriteTo;
@property (assign, nonatomic) BOOL showArchived;
@property (assign, nonatomic) NSInteger logLevel;

+(void)configure;
+(void)configureWith:(NSDictionary *)config;

+(ChatManager *)getInstance;
-(void)getContactLocalDB:(NSString *)userid withCompletion:(void(^)(ChatUser *user))callback;
-(void)getUserInfoRemote:(NSString *)userid withCompletion:(void(^)(ChatUser *user))callback;

-(void)addConversationHandler:(ChatConversationHandler *)handler;
-(ChatConversationsHandler *)getAndStartConversationsHandler;
//-(ChatConversationHandler *)getConversationHandlerForRecipient:(ChatUser *)recipient;
//-(ChatConversationHandler *)getConversationHandlerForGroup:(ChatGroup *)group;
-(void)getConversationHandlerForRecipient:(ChatUser *)recipient completion:(void(^)(ChatConversationHandler *)) callback;
-(void)getConversationHandlerForGroup:(ChatGroup *)group completion:(void(^)(ChatConversationHandler *)) callback;
//-(void)startConversationHandler:(ChatConversation *)conv;

-(ChatConversationsHandler *)createConversationsHandler;
-(ChatPresenceHandler *)createPresenceHandler;
-(ChatGroupsHandler *)createGroupsHandlerForUser:(ChatUser *)user;
-(ChatContactsSynchronizer *)createContactsSynchronizerForUser:(ChatUser *)user;

-(void)registerForNotifications:(NSData *)devToken;

-(void)startWithUser:(ChatUser *)user;
-(void)dispose;

// === GROUPS ===

// se errore aggiorna conversazione-gruppo locale (DB, creata dopo) con messaggio errore, stato "riprova" e menù "riprova" (vedi creazione gruppo whatsapp in modalità "aereo").

-(NSString *)newGroupId;
-(void)addMember:(NSString *)user_id toGroup:(ChatGroup *)group withCompletionBlock:(void (^)(NSError *))completionBlock;
-(void)removeMember:(NSString *)user_id fromGroup:(ChatGroup *)group withCompletionBlock:(void (^)(NSError *))completionBlock;
+(ChatGroup *)groupFromSnapshotFactory:(FIRDataSnapshot *)snapshot;
-(ChatGroup *)groupById:(NSString *)groupId;
-(void)createGroup:(ChatGroup *)group withCompletionBlock:(void (^)(ChatGroup *group, NSError* error))callback;
-(void)updateGroupName:(NSString *)name forGroup:(ChatGroup *)group withCompletionBlock:(void (^)(NSError *))completionBlock;
-(NSDictionary *)allGroups;

// === CONVERSATIONS ===

-(void)removeConversation:(ChatConversation *)conversation;
-(void)updateConversationIsNew:(FIRDatabaseReference *)conversationRef is_new:(int)is_new;

// === CONTACTS ===
-(void)createContactFor:(ChatUser *)user withCompletionBlock:(void (^)(NSError *))completionBlock;
-(void)updateContactFor:(NSString *)userId ImageChagedWithCompletionBlock:(void (^)(NSError *))completionBlock;

-(void)removeInstanceId;
-(void)loadGroup:(NSString *)group_id completion:(void (^)(ChatGroup* group, BOOL error))callback;

-(FIRStorageReference *)uploadProfileImage:(UIImage *)image profileId:(NSString *)profileId completion:(void(^)(NSString *downloadURL, NSError *error))callback progressCallback:(void(^)(double fraction))progressCallback;
-(void)deleteProfileImage:(NSString *)profileId completion:(void(^)(NSError *error))callback;

// profile image
// paths
+(NSString *)filePathOfProfile:(NSString *)profileId fileName:(NSString *)fileName;
+(NSString *)profileImagePathOf:(NSString *)profileId;
// URLs
+(NSString *)profileImageURLOf:(NSString *)profileId;
+(NSString *)profileThumbImageURLOf:(NSString *)profileId;
+(NSString *)fileURLOfProfile:(NSString *)profileId fileName:(NSString *)fileName;
+(NSString *)profileBaseURL:(NSString *)profileId;

// LOG
+(void)logDebug:(NSString*)text, ...;
+(void)logInfo:(NSString*)text, ...;
+(void)logError:(NSString*)text, ...;
+(void)logWarn:(NSString*)text, ...;

@property (nonatomic, copy) ChatMessage *(^onBeforeMessageSend)(ChatMessage *msg);
@property (nonatomic, copy) ChatMessage *(^onMessageNew)(ChatMessage *msg);
@property (nonatomic, copy) ChatMessage *(^onMessageUpdate)(ChatMessage *msg);
@property (nonatomic, copy) ChatConversation *(^onCoversationArrived)(ChatConversation *conv);
@property (nonatomic, copy) ChatConversation *(^onCoversationUpdated)(ChatConversation *conv);

@end

