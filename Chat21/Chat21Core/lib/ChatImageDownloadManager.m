//
//  ChatImageDownloadManager.m
//  chat21
//
//  Created by Andrea Sponziello on 06/05/2018.
//  Copyright © 2018 Frontiere21. All rights reserved.
//

#import "ChatImageDownloadManager.h"
#import "ChatMessage.h"
#import "ChatImageCache.h"
#import "ChatManager.h"

@implementation ChatImageDownloadManager

-(id)init {
    self = [super init];
    if (self) {
        self.tasks = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)downloadImage:(ChatMessage *)message onIndexPath:(NSIndexPath *)indexPath completionHandler:(void(^)(NSIndexPath* indexPath, UIImage *image, NSError *error))callback {
    NSURLSessionDataTask *currentTask = [self.tasks objectForKey:message.messageId];
    if (currentTask) {
        [ChatManager logDebug:@"Image %@ already downloading (messageId: %@).", message.imageURL, message.messageId];
        return;
    }
    NSURLSessionConfiguration *_config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *_session = [NSURLSession sessionWithConfiguration:_config];
    NSURL *url = [NSURL URLWithString:message.imageURL];
    [ChatManager logDebug:@"Downloading image. URL: %@", message.imageURL];
    if (!url) {
        [ChatManager logDebug:@"ERROR - Can't download image, URL is null"];
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
    NSURLSessionDataTask *task = [_session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [ChatManager logDebug:@"Image downloaded: %@", message.imageURL];
        [self.tasks removeObjectForKey:message.messageId];
        if (error) {
            [ChatManager logDebug:@"%@", error];
            callback(indexPath, nil, error);
            return;
        }
        
        if (data) {
            UIImage *image = [UIImage imageWithData:data];
            if (image) {
                NSData* imageData = [NSData dataWithData:UIImagePNGRepresentation(image)];
                NSString *path = [message imagePathFromMediaFolder];
                [ChatManager logDebug:@"Saving image to: %@", path];
                NSError *writeError = nil;
                [message createMediaFolderPathIfNotExists];
                if(![imageData writeToFile:path options:NSDataWritingAtomic error:&writeError]) {
                    [ChatManager logDebug:@"%@: Error saving image: %@", [self class], [writeError localizedDescription]];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    callback(indexPath, image, nil);
                });
            }
        }
    }];
    [self.tasks setObject:task forKey:message.messageId];
    [task resume];
}

@end
