//
//  ChatSelectContactProtocol.h
//  Chat21
//
//  Created by Andrea Sponziello on 04/11/2019.
//

@class ChatUser;

@protocol ChatSelectContactProtocol

@required

@property (nonatomic, copy) void (^ _Nullable completionCallback)( ChatUser * _Nullable contact, BOOL canceled);

@end
