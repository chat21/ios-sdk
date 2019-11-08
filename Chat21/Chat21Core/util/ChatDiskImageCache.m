//
//  ChatDiskImageCache.m
//  chat21
//
//  Created by Andrea Sponziello on 27/08/2018.
//  Copyright © 2018 Frontiere21. All rights reserved.
//

#import "ChatDiskImageCache.h"
#import <Foundation/Foundation.h>
#import "ChatImageUtil.h"
#import "ChatUtil.h"
#import "ChatManager.h"

static ChatDiskImageCache *sharedInstance = nil;

@implementation ChatDiskImageCache

-(id)init
{
    if (self = [super init])
    {
        self.memoryObjects = [[NSMutableDictionary alloc] init];
        self.cacheFolder = @"profileImageCache";
        self.maxSize = 50;
        self.tasks = [[NSMutableDictionary alloc] init];
    }
    return self;
}

+(ChatDiskImageCache *)getSharedInstance {
    if (!sharedInstance) {
        sharedInstance = [[super alloc] init];
    }
    return sharedInstance;
}

-(void)addImageToCache:(UIImage *)image withKey:(NSString *)key {
    [ChatManager logDebug:@"adding for key: %@", key];
    if (key == nil || image == nil) {
        return;
    }
//    [self.memoryObjects setObject:image forKey:key];
    [self addImageToMemoryCache:image withKey:key];
    [ChatImageUtil saveImageAsPNG:image withName:key inFolder:self.cacheFolder];
}

-(void)addImageToMemoryCache:(UIImage *)image withKey:(NSString *)key {
    [ChatManager logDebug:@"adding to memory for key: %@", key];
    if (key == nil || image == nil) {
        return;
    }
    [self.memoryObjects setObject:image forKey:key];
}

-(void)deleteImageFromCacheWithKey:(NSString *)key {
    [self.memoryObjects removeObjectForKey:key];
    [ChatDiskImageCache deleteFileWithName:key inFolder:self.cacheFolder];
}

-(void)deleteFilesFromDiskCacheOfProfile:(NSString *)profileId {
    NSString *baseURL = [ChatManager profileBaseURL:profileId];
    NSURL *url = [NSURL URLWithString:baseURL];
    NSString *cache_key = [ChatDiskImageCache urlAsKey:url];
    [self deleteFilesFromCacheStartingWith:cache_key];
}

-(void)deleteFilesFromCacheStartingWith:(NSString *)partial_key {
    NSString *folder_path = [ChatUtil absoluteFolderPath:self.cacheFolder]; // cache folder path
    [ChatManager logDebug:@"deleting files at folder path: %@ starting with: %@", folder_path, partial_key];
    NSFileManager *filemgr = [NSFileManager defaultManager];
    NSArray *directoryList = [filemgr contentsOfDirectoryAtPath:folder_path error:nil];
    for (NSString *filename in directoryList) {
        if ([filename hasPrefix:partial_key]) {
            NSString *file_path = [folder_path stringByAppendingPathComponent:filename];
            NSError *error;
            [filemgr removeItemAtPath:file_path error:&error];
            if (error) {
                [ChatManager logError:@"Error removing file in cache path? (%@) - %@",file_path, error];
            }
        }
    }
}

-(UIImage *)getCachedImage:(NSString *)key {
    return [self getCachedImage:key sized:0 circle:NO];
}

-(void)removeCachedImage:(NSString *)key sized:(long)size {
    NSString *sized_key = key;
    if (size != 0) {
        sized_key = [ChatDiskImageCache sizedKey:key size:size];
    }
    [ChatManager logDebug:@"sized_key %@", sized_key];
    [self deleteImageFromCacheWithKey:sized_key];
}

-(UIImage *)getCachedImage:(NSString *)key sized:(long)size circle:(BOOL)circle {
    NSString *sized_key = key;
    if (size != 0) {
        sized_key =[ChatDiskImageCache sizedKey:key size:size];
    }
    // hit memory first
    UIImage *image = (UIImage *)[self.memoryObjects objectForKey:sized_key];
    if (!image) {
        image = [ChatDiskImageCache loadImage:sized_key inFolder:self.cacheFolder];
        if (!image && size != 0) {
            // a resized image was requested, not the original one, then...
            // get the original one
            UIImage *original_image = [ChatDiskImageCache loadImage:key inFolder:self.cacheFolder];
            if (original_image) {
                // we have the original image.
                // resizing...
                UIImage *resized_image = [ChatImageUtil scaleImage:original_image toSize:CGSizeMake(size, size)];
                if (circle) {
                    resized_image = [ChatImageUtil circleImage:resized_image];
                }
                [self addImageToCache:resized_image withKey:sized_key];
                image = resized_image;
            }
        }
        else if (image != nil) {
            [self.memoryObjects setObject:image forKey:sized_key];
        }
    }
    return image;
}

+(NSString *)sizedKey:(NSString *)key size:(long) size {
    return [NSString stringWithFormat:@"%@_sized_%ld.png", key, size];
}

+(UIImage *)loadImage:(NSString *)fileName inFolder:(NSString *)folderName {
    NSString *folder_path = [ChatUtil absoluteFolderPath:folderName]; // cache folder path
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *image_path = [folder_path stringByAppendingPathComponent:fileName];
    BOOL fileExist = [fileManager fileExistsAtPath:image_path];
    UIImage *image;
    if (fileExist) {
        NSDictionary* fileAttribs = [[NSFileManager defaultManager] attributesOfItemAtPath:image_path error:nil];
        NSDate *modificationDate = (NSDate*)[fileAttribs objectForKey:NSFileModificationDate];
        [ChatManager logDebug:@"Modification date %@", modificationDate];
        image = [UIImage imageWithContentsOfFile:image_path];
    }
    return image;
}

+(void)deleteFileWithName:(NSString*)fileName inFolder:(NSString *)folderName {
    NSString *folder_path = [ChatUtil absoluteFolderPath:folderName]; // cache folder path
    NSString *image_path = [folder_path stringByAppendingPathComponent:fileName];
    NSFileManager *filemgr = [NSFileManager defaultManager];
    NSError *error;
    [filemgr removeItemAtPath:image_path error:&error];
    if (error) {
        [ChatManager logDebug:@"Error removing image to cache path? (%@) - %@",image_path, error];
    }
}

- (NSURLSessionDataTask *)getImage:(NSString *)imageURL completionHandler:(void(^)(NSString *imageURL, UIImage *image))callback {
    return [self getImage:imageURL sized:0 circle:NO completionHandler:^(NSString *imageURL, UIImage *image) {
        callback(imageURL, image);
    }];
}

- (NSURLSessionDataTask *)getImage:(NSString *)imageURL sized:(long)size circle:(BOOL)circle completionHandler:(void(^)(NSString *imageURL, UIImage *image))callback {
    [ChatManager logDebug:@"Cache image url requested: %@", imageURL];
    NSURL *url = [NSURL URLWithString:imageURL];
    NSString *cache_key = [ChatDiskImageCache urlAsKey:url];
    UIImage *image = [self getCachedImage:cache_key sized:size circle:circle];
    if (image) {
        callback(imageURL, image);
        return nil;
    }
    NSURLSessionDataTask *currentTask = [self.tasks objectForKey:imageURL];
    if (currentTask) {
        [ChatManager logDebug:@"Image %@ already downloading.", imageURL];
        callback(imageURL, nil);
        return nil;
    }
    
    [ChatManager logDebug:@"Downloading image. URL: %@", imageURL];
    if (!url) {
        [ChatManager logDebug:@"ERROR - Can't download image, URL is null"];
        callback(imageURL, nil);
        return nil;
    }
    
    NSURLSessionConfiguration *_config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *_session = [NSURLSession sessionWithConfiguration:_config];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
    NSURLSessionDataTask *task = [_session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [ChatManager logDebug:@"Image downloaded: %@", imageURL];
        [self.tasks removeObjectForKey:imageURL];
        if (error) {
            [ChatManager logError:@"ERRORR: %@ > %@", imageURL, error];
            callback(imageURL, nil);
            return;
        }
        if (data) {
            UIImage *image = [UIImage imageWithData:data];
            if (image) {
                [self addImageToCache:image withKey:cache_key];
                if (size != 0) {
                    image = [self getCachedImage:cache_key sized:size circle:circle];
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(imageURL, image);
            });
        }
    }];
    [self.tasks setObject:task forKey:imageURL];
    [task resume];
    return task;
}

-(UIImage *)smallImageOf:(NSString *)profileId {
    return nil;
}

+(NSString *)urlAsKey:(NSURL *)url {
    NSArray<NSString *> *components = [url pathComponents];
    NSString *key = [[components componentsJoinedByString:@"_"] stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return key;
}

-(void)updateProfile:(NSString *)profileId image:(UIImage *)image {
    
    [self removeCachedImagesOfProfile:profileId];
    
    NSString *imageURL = [ChatManager profileImageURLOf:profileId];
    NSString *imageKey = [ChatDiskImageCache urlAsKey:[NSURL URLWithString:imageURL]];
    [self addImageToCache:image withKey:imageKey];
    
    // adds also a local thumb in cache.
    NSString *thumbImageURL = [ChatManager profileThumbImageURLOf:profileId];
    NSString *thumbImageKey = [ChatDiskImageCache urlAsKey:[NSURL URLWithString:thumbImageURL]];
    [self addImageToCache:image withKey:thumbImageKey];
}

-(void)removeCachedImagesOfProfile:(NSString *)profileId {
    [self deleteObjectsFromMemoryCacheOfProfile:profileId];
    [self deleteFilesFromDiskCacheOfProfile:profileId];
}

-(void)deleteObjectsFromMemoryCacheOfProfile:(NSString *)profileId {
    NSString *baseURL = [ChatManager profileBaseURL:profileId];
    NSURL *url = [NSURL URLWithString:baseURL];
    NSString *cache_key = [ChatDiskImageCache urlAsKey:url];
    [self deleteObjectsFromMemoryStartingWith:cache_key];
}

-(void)deleteObjectsFromMemoryStartingWith:(NSString *)partial_key {
    NSArray *keys = [self.memoryObjects allKeys];
    for(NSString *key in keys) {
        if ([partial_key hasPrefix:partial_key]) {
            [self.memoryObjects removeObjectForKey:key];
        }
    }
}

-(UIImage *)smallCachedProfileImageFor:(NSString *)profileId {
    NSString *thumb_photo_url = [ChatManager profileThumbImageURLOf:profileId];
    // thumb url used as cache-key
    NSURL *url = [NSURL URLWithString:thumb_photo_url];
    NSString *thumb_key = [ChatDiskImageCache urlAsKey:url];
    UIImage *image = [self getCachedImage:thumb_key];
    [ChatManager logDebug:@"image: %@", image];
    return image;
}

- (void)createThumbsInCacheForProfileId:(NSString *)profileId originalImage:(UIImage *)originalImage {
    // adds to cache the thumb version (computed locally from the original version just downloaded), without need to download it again
    NSString *thumb_photo_url = [ChatManager profileThumbImageURLOf:profileId];
    // thumb url used as cache-key
    NSURL *url = [NSURL URLWithString:thumb_photo_url];
    NSString *thumb_key = [ChatDiskImageCache urlAsKey:url];
    // creates the thumb image
    UIImage *thumb_image = [ChatImageUtil scaleImage:originalImage toSize:CGSizeMake(SMALL_PROFILE_IMAGE_SIZE, SMALL_PROFILE_IMAGE_SIZE)];
    // adds to cache the thumb image
    [self addImageToCache:thumb_image withKey:thumb_key];
    UIImage *resized_image = [ChatImageUtil circleImage:thumb_image];
    // adds to cache the resized-circle image for conversations list
    NSString *resized_key = [ChatDiskImageCache sizedKey:thumb_key size:SMALL_PROFILE_IMAGE_SIZE];
    [self addImageToCache:resized_image withKey:resized_key];
}

@end
