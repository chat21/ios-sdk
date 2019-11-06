//
//  ChatContactsDB.m
//
//
//  Created by Andrea Sponziello on 17/09/2017.
//
//

#import "ChatContactsDB.h"
#import "ChatUser.h"
#import "ChatManager.h"

static ChatContactsDB *sharedInstance = nil;
//static sqlite3 *database = nil;
//static sqlite3_stmt *statement = nil;
//static sqlite3_stmt *statement_insert = nil;

@interface ChatContactsDB () {
    dispatch_queue_t serialDatabaseQueue;
    sqlite3 *database;
    sqlite3_stmt *statement;
    sqlite3_stmt *statement_insert;
}
@end

@implementation ChatContactsDB

+(ChatContactsDB *)getSharedInstance {
    if (!sharedInstance) {
        sharedInstance = [[super alloc] init];
    }
    return sharedInstance;
}

-(id)init {
    if (self = [super init]) {
        serialDatabaseQueue = dispatch_queue_create("db.sqllite", DISPATCH_QUEUE_SERIAL);
        self.logQuery = NO;
        database = nil;
        statement = nil;
        statement_insert = nil;
    }
    return self;
}

// name only [a-zA-Z0-9_]
-(BOOL)createDBWithName:(NSString *)name {
    NSString *docsDir;
    NSURL *urlPath = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    docsDir = urlPath.path;
    NSString *db_name = nil;
    if (name) {
        db_name = [[NSString alloc] initWithFormat:@"%@_contacts.db", name];
    }
    databasePath = [[NSString alloc] initWithString:
                    [docsDir stringByAppendingPathComponent: db_name]];
    [ChatManager logDebug:@"Init database: %@", databasePath];
    BOOL isSuccess = YES;
    NSFileManager *filemgr = [NSFileManager defaultManager];
    
    // **** TESTING ONLY ****
//    [self drop_database];
    const char *dbpath = [databasePath UTF8String];
    
    if ([filemgr fileExistsAtPath: databasePath ] == NO) {
        [ChatManager logDebug:@"Database %@ not exists. Creating...", databasePath];
        int result;
        result = sqlite3_open_v2(dbpath, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, NULL);
        if (result == SQLITE_OK) {
            char *errMsg;
            if (self.logQuery) {[ChatManager logDebug:@"**** CREATING TABLE CONTACTS..."];}
            const char *sql_stmt_contacts =
            "create table if not exists contacts (contactId text primary key, firstname text, lastname text, fullname text, email text, imageurl text, createdon integer)";
            if (sqlite3_exec(database, sql_stmt_contacts, NULL, NULL, &errMsg) != SQLITE_OK) {
                isSuccess = NO;
                [ChatManager logError:@"Failed to create table contacts. ERROR: %s", errMsg];
            }
            else {
                [ChatManager logDebug:@"Table contacts successfully created."];
                [self upgradeSchema:dbpath];
            }
            return  isSuccess;
        }
        else {
            isSuccess = NO;
            [ChatManager logError:@"Failed to open/create database"];
        }
    } else {
        [ChatManager logDebug:@"Database %@ already exists. Opening.", databasePath];
        if (sqlite3_open(dbpath, &database) == SQLITE_OK) {
//            [self upgradeSchema:dbpath];
            return  isSuccess;
        }
        else {
            isSuccess = NO;
            [ChatManager logError:@"Failed to open database."];
        }
    }
    return isSuccess;
}

-(void)upgradeSchema:(const char *)dbpath {
    // version schema
    // or test if the column exists
    // https://stackoverflow.com/questions/3604310/alter-table-add-column-if-not-exists-in-sqlite
    if (self.logQuery) {[ChatManager logDebug:@"Upgrading schema"];}
    int result;
    result = sqlite3_open_v2(dbpath, &database, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, NULL);
    if (result == SQLITE_OK) {
        if (self.logQuery) {[ChatManager logDebug:@"**** UPGRADING TABLE contacts..."];}
        
        if (self.logQuery) {[ChatManager logDebug:@"alter table contacts add column imagechangedat integer"];}
        char *errMsg;
        const char *sql_stmt_alter =
        "alter table contacts add column imagechangedat integer";
        if (sqlite3_exec(database, sql_stmt_alter, NULL, NULL, &errMsg) != SQLITE_OK) {
            if (self.logQuery) {[ChatManager logDebug:@"Failed to alter table contacts (adding column 'imagechangedat integer')"];}
        }
        else {
            if (self.logQuery) {[ChatManager logDebug:@"Table contacts successfully altered (added 'imagechangedat integer')."];}
        }
        sqlite3_close(database);
    }
    else {
        if (self.logQuery) {[ChatManager logDebug:@"Failed to alter table messages."];}
    }
}

// only for test
//-(void)drop_database {
//    [ChatManager logDebug:@"DROPPING ARCHIVE: %@", databasePath];
//    NSFileManager *filemgr = [NSFileManager defaultManager];
//    if ([filemgr fileExistsAtPath: databasePath ] == YES) {
//        NSError *error;
//        [filemgr removeItemAtPath:databasePath error:&error];
//        if (error){
//            [ChatManager logError:@"%@", error];
//        }
//    }
//}

// *************
// CONTACTS
// *************

-(void)insertOrUpdateContactSyncronized:(ChatUser *)contact completion:(void(^)(void)) callback {
    dispatch_async(serialDatabaseQueue, ^{
        [self getContactByIdSyncronized:contact.userId completion:^(ChatUser *user) {
            if (user) {
                [self updateContact:contact];
                if (callback != nil) {
                    callback();
                }
            }
            else {
                [self insertContact:contact];
                if (callback != nil) {
                    callback();
                }
            }
        }];
    });
}

-(BOOL)insertContact:(ChatUser *)contact {
    [ChatManager logDebug:@"Insert contact %@", contact.fullname];
    NSString *insertSQL = [NSString stringWithFormat:@"insert into contacts (contactId, firstname, lastname, fullname, email, imagechangedat, createdon) values (?, ?, ?, ?, ?, ?, ?)"];
    
    sqlite3_prepare(database, [insertSQL UTF8String], -1, &statement_insert, NULL);
    
    sqlite3_bind_text(statement_insert, 1, [contact.userId UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(statement_insert, 2, [contact.firstname UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(statement_insert, 3, [contact.lastname UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(statement_insert, 4, [contact.fullname UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(statement_insert, 5, [contact.email UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(statement_insert, 6, (long)contact.imageChangedAt);
    sqlite3_bind_int64(statement_insert, 7, (long)contact.createdon);
    
    if (sqlite3_step(statement_insert) == SQLITE_DONE) {
        sqlite3_finalize(statement_insert);
        return YES;
    }
    else {
        [ChatManager logError:@"Database returned error %d: %s", sqlite3_errcode(database), sqlite3_errmsg(database)];
        sqlite3_reset(statement_insert);
        return NO;
    }
    return NO;
}

-(BOOL)updateContact:(ChatUser *)contact {
    [ChatManager logDebug:@"Update contact %@", contact.fullname];
    NSString *updateSQL = [NSString stringWithFormat:@"UPDATE contacts SET firstname = ?, lastname = ?, fullname = ?, email = ?, imagechangedat = ?, createdon = ? WHERE contactId = ?"];
    
    sqlite3_prepare(database, [updateSQL UTF8String], -1, &statement, NULL);
    
    sqlite3_bind_text(statement, 1, [contact.firstname UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(statement, 2, [contact.lastname UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(statement, 3, [contact.fullname UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(statement, 4, [contact.email UTF8String], -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(statement, 5, (long)contact.imageChangedAt);
    sqlite3_bind_int64(statement, 6, (long)contact.createdon);
    sqlite3_bind_text(statement, 7, [contact.userId UTF8String], -1, SQLITE_TRANSIENT);
    
    if (sqlite3_step(statement) == SQLITE_DONE) {
        sqlite3_reset(statement);
        [ChatManager logDebug:@"Contact successfully updated."];
        return YES;
    }
    else {
        [ChatManager logDebug:@"Database returned error %d: %s", sqlite3_errcode(database), sqlite3_errmsg(database)];
        sqlite3_reset(statement);
        return NO;
    }
    return NO;
}

static NSString *SELECT_FROM_CONTACTS_STATEMENT = @"SELECT contactId, firstname, lastname, fullname, email, imagechangedat, createdon FROM contacts ";

-(NSArray*)getAllContacts {
    NSMutableArray *contacts = [[NSMutableArray alloc] init];
    NSString *querySQL = [NSString stringWithFormat:@"%@ order by fullname desc", SELECT_FROM_CONTACTS_STATEMENT];
    const char *query_stmt = [querySQL UTF8String];
    if (sqlite3_prepare_v2(database, query_stmt, -1, &statement, NULL) == SQLITE_OK) {
        while (sqlite3_step(statement) == SQLITE_ROW) {
            ChatUser *contact = [self contactFromStatement:statement];
            [contacts addObject:contact];
        }
        sqlite3_reset(statement);
    } else {
        [ChatManager logError:@"Database returned error %d: %s", sqlite3_errcode(database), sqlite3_errmsg(database)];
    }
    return contacts;
}

-(void)getMostRecentContactSyncronizedWithCompletion:(void(^)(ChatUser *contact)) callback {
    dispatch_async(serialDatabaseQueue, ^{
        ChatUser *contact = [self getMostRecentContact];
        callback(contact);
    });
}

-(ChatUser *)getMostRecentContact {
    ChatUser *contact;
    const char *dbpath = [databasePath UTF8String];
    if (sqlite3_open(dbpath, &database) == SQLITE_OK) {
        NSString *querySQL = [NSString stringWithFormat:@"%@ order by createdon desc LIMIT 1", SELECT_FROM_CONTACTS_STATEMENT];
        const char *query_stmt = [querySQL UTF8String];
        if (sqlite3_prepare_v2(database, query_stmt, -1, &statement, NULL) == SQLITE_OK) {
            while (sqlite3_step(statement) == SQLITE_ROW) {
                contact = [self contactFromStatement:statement];
            }
            sqlite3_reset(statement);
        } else {
            [ChatManager logError:@"Database returned error %d: %s", sqlite3_errcode(database), sqlite3_errmsg(database)];
        }
    }
    return contact;
}

-(void)getContactByIdSyncronized:(NSString *)contactId completion:(void(^)(ChatUser *)) callback {
    dispatch_async(serialDatabaseQueue, ^{
        ChatUser *user = [self getContactById:contactId];
        if (callback != nil) {
            callback(user);
        }
    });
}

-(void)getMultipleContactsByIdsSyncronized:(NSArray<NSString *> *)contactIds completion:(void(^)(NSArray<ChatUser *> *)) callback {
    dispatch_async(serialDatabaseQueue, ^{
        NSArray<ChatUser *> *users = [self getMultipleContactsByIds:contactIds];
        if (callback != nil) {
            callback(users);
        }
    });
}

-(ChatUser *)getContactById:(NSString *)contactId {
    ChatUser *contact = nil;
    NSString *querySQL = [NSString stringWithFormat:
                          @"%@ where contactId = \"%@\"",SELECT_FROM_CONTACTS_STATEMENT, contactId];
    const char *query_stmt = [querySQL UTF8String];
    if (sqlite3_prepare_v2(database, query_stmt, -1, &statement, NULL) == SQLITE_OK) {
        while (sqlite3_step(statement) == SQLITE_ROW) {
            contact = [self contactFromStatement:statement];
        }
        sqlite3_reset(statement);
    } else {
        [ChatManager logError:@"**** PROBLEMS WHILE QUERYING CONTACTS..."];
        [ChatManager logError:@"Database returned error %d: %s", sqlite3_errcode(database), sqlite3_errmsg(database)];
    }
    return contact;
}

-(NSArray<ChatUser *> *)getMultipleContactsByIds:(NSArray *)contactIds {
    [ChatManager logDebug:@"Searching multiple contacts by ids: %@", contactIds];
    NSMutableArray<ChatUser *> *contacts = [[NSMutableArray alloc] init];
    if (contactIds.count == 0) {
        return contacts;
    }
    NSString *last_contact_id = [contactIds lastObject];
    NSString *contactsIds_query_part = @"(";
    NSString *id_for_query;
    for (NSString *contact_id in contactIds) {
        if (contact_id != last_contact_id) {
            id_for_query = [[NSString alloc] initWithFormat:@"'%@', ", contact_id];
        }
        else {
            id_for_query = [[NSString alloc] initWithFormat:@"'%@')", contact_id];
        }
        contactsIds_query_part = [contactsIds_query_part stringByAppendingString:id_for_query];
    }
    NSString *querySQL = [NSString stringWithFormat:
                          @"%@ where contactId in %@", SELECT_FROM_CONTACTS_STATEMENT, contactsIds_query_part];
    const char *query_stmt = [querySQL UTF8String];
    if (sqlite3_prepare_v2(database, query_stmt, -1, &statement, NULL) == SQLITE_OK) {
        while (sqlite3_step(statement) == SQLITE_ROW) {
            ChatUser *contact = [self contactFromStatement:statement];
            [contacts addObject:contact];
        }
        sqlite3_reset(statement);
    } else {
        [ChatManager logDebug:@"Database returned error %d: %s", sqlite3_errcode(database), sqlite3_errmsg(database)];
    }
    return contacts;
}

-(void)searchContactsByFullnameSynchronized:(NSString *)searchString completion:(void (^)(NSArray<ChatUser *> *))callback {
    dispatch_async(serialDatabaseQueue, ^{
        NSMutableArray<ChatUser *> *contacts = [[NSMutableArray alloc] init];
        NSString *querySQL = [NSString stringWithFormat:
                              @"%@ WHERE fullname LIKE \"%%%@%%\" ORDER BY fullname",SELECT_FROM_CONTACTS_STATEMENT, searchString]; //  LIMIT 50
        const char *query_stmt = [querySQL UTF8String];
        if (sqlite3_prepare_v2(self->database, query_stmt, -1, &self->statement, NULL) == SQLITE_OK) {
            while (sqlite3_step(self->statement) == SQLITE_ROW) {
                ChatUser *contact = [self contactFromStatement:self->statement];
                [contacts addObject:contact];
            }
            sqlite3_reset(self->statement);
        } else {
            [ChatManager logError:@"Database returned error %d: %s", sqlite3_errcode(self->database), sqlite3_errmsg(self->database)];
        }
        if (callback != nil) {
            callback(contacts);
        }
    });
}

-(void)removeContactSynchronized:(NSString *)contactId completion:(void(^)(void)) callback {
    dispatch_async(serialDatabaseQueue, ^{
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM contacts WHERE contactId = \"%@\"", contactId];
        const char *stmt = [sql UTF8String];
        sqlite3_prepare_v2(self->database, stmt,-1, &self->statement, NULL);
        if (sqlite3_step(self->statement) == SQLITE_DONE) {
            sqlite3_reset(self->statement);
        }
        else {
            [ChatManager logDebug:@"Database returned error %d: %s", sqlite3_errcode(self->database), sqlite3_errmsg(self->database)];
            sqlite3_reset(self->statement);
        }
        if (callback != nil) {
            callback();
        }
    });
}

-(ChatUser *)contactFromStatement:(sqlite3_stmt *)statement {
    const char* _contactId = (const char *) sqlite3_column_text(statement, 0);
    NSString *contactId = nil;
    if (_contactId) {
        contactId = [[NSString alloc] initWithUTF8String:_contactId];
    }
    const char* _firstname = (const char *) sqlite3_column_text(statement, 1);
    NSString *firstname = nil;
    if (_firstname) {
        firstname = [[NSString alloc] initWithUTF8String:_firstname];
    }
    
    const char* _lastname = (const char *) sqlite3_column_text(statement, 2);
    NSString *lastname = nil;
    if (_lastname) {
        lastname = [[NSString alloc] initWithUTF8String:_lastname];
    }
    
    const char* _fullname = (const char *) sqlite3_column_text(statement, 3);
    NSString *fullname = nil;
    if (_fullname) {
        fullname = [[NSString alloc] initWithUTF8String:_fullname];
    }
    
    const char* _email = (const char *) sqlite3_column_text(statement, 4);
    NSString *email = nil;
    if (_email) {
        email = [[NSString alloc] initWithUTF8String:_email];
    }
    
    const long imagechangedat = (const long) sqlite3_column_int64(statement, 5);
    
    const long createdon = (const long) sqlite3_column_int64(statement, 6);
    
    ChatUser *contact = [[ChatUser alloc] init];
    contact.userId = contactId;
    contact.firstname = firstname;
    contact.lastname = lastname;
    contact.fullname = fullname;
    contact.email = email;
    contact.imageChangedAt = imagechangedat;
    contact.createdon = createdon;
    return contact;
}

@end

