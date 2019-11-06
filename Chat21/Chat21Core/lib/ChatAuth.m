//
//  ChatAuth.m
//  chat21
//
//  Created by Andrea Sponziello on 05/02/2018.
//  Copyright © 2018 Frontiere21. All rights reserved.
//

#import "ChatAuth.h"
#import "ChatUser.h"
#import "FirebaseAuth/FIRAuth.h"
#import "FirebaseAuth/FIRUser.h"
#import "ChatManager.h"

@implementation ChatAuth

+(void)createUserWithEmail:(NSString *)email password:(NSString *)password completion:(void (^)(ChatUser *user, NSError *error))callback {
    [[FIRAuth auth] createUserWithEmail:email
                              password:password
                            completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
        if (error) {
            [ChatManager logDebug:@"Firebase Register error for email %@: %@", email, error];
            callback(nil, error);
        }
        else {
            FIRUser *fir_user = authResult.user;
            ChatUser *chatuser = [[ChatUser alloc] init];
            chatuser.userId = fir_user.uid;
            chatuser.email = email;
            callback(chatuser, nil);
        }
    }];
}

+(void)authWithEmail:(NSString *)email password:(NSString *)password completion:(void (^)(ChatUser *user, NSError *))callback {
    [[FIRAuth auth] signInWithEmail:email password:password completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
        if (error) {
            [ChatManager logDebug:@"Firebase Auth error for email %@/%@: %@", email, password, error];
            callback(nil, error);
        }
        else {
            FIRUser *user = authResult.user;
            [ChatManager logDebug:@"Firebase Auth success. email: %@, emailverified: %d, userid: %@", user.email, user.emailVerified, user.uid];
            ChatUser *chatuser = [[ChatUser alloc] init];
            chatuser.userId = user.uid;
            chatuser.email = user.email;
            callback(chatuser, nil);
        }
    }];
}

+(void)authWithCustomToken:(NSString *)token completion:(void (^)(ChatUser *user, NSError *))callback {
    [[FIRAuth auth] signInWithCustomToken:token completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
        if (error) {
            [ChatManager logDebug:@"Firebase Auth error for token %@: %@", token, error];
            callback(nil, error);
        }
        else {
            FIRUser *user = authResult.user;
            [ChatManager logDebug:@"Firebase Auth success. email: %@, emailverified: %d, userid: %@", user.email, user.emailVerified, user.uid];
            ChatUser *chatuser = [[ChatUser alloc] init];
            chatuser.userId = user.uid;
            chatuser.email = user.email;
            callback(chatuser, nil);
        }
    }];
}

+(void)authAnonymousWithCompletion:(void (^)(ChatUser *user, NSError *))callback {
    [[FIRAuth auth] signInAnonymouslyWithCompletion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
        if (error) {
            [ChatManager logDebug:@"Firebase Anonymous Auth error"];
            callback(nil, error);
        }
        else {
            FIRUser *user = authResult.user;
            [ChatManager logDebug:@"Firebase Anonymous Auth success. userid: %@", user.uid];
            ChatUser *chatuser = [[ChatUser alloc] init];
            chatuser.userId = user.uid;
            callback(chatuser, nil);
        }
    }];
}

+(void)test1 {
    
}
@end
