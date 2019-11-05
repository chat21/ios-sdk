//
//  ChatAuth.h
//  chat21
//
//  Created by Andrea Sponziello on 05/02/2018.
//  Copyright © 2018 Frontiere21. All rights reserved.
//

#import <Foundation/Foundation.h>
@class ChatUser;

@interface ChatAuth : NSObject

+(void)createUserWithEmail:(NSString *)email password:(NSString *)password completion:(void (^)(ChatUser *user, NSError *))callback;
+(void)authWithEmail:(NSString *)email password:(NSString *)password completion:(void (^)(ChatUser *user, NSError *))callback;
+(void)authWithCustomToken:(NSString *)token completion:(void (^)(ChatUser *user, NSError *))callback;
+(void)authAnonymousWithCompletion:(void (^)(ChatUser *user, NSError *))callback;

@end
