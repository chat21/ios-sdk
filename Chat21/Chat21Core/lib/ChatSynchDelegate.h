//
//  ChatSynchDelegate.h
//
//  Created by Andrea Sponziello on 10/10/2017.
//  Copyright © 2017 Frontiere21. All rights reserved.
//

@class ChatUser;

@protocol ChatSynchDelegate
@required
- (void)synchEnd;
- (void)synchStart;
- (void)contactUpdated:(ChatUser *)oldContact newContact:(ChatUser *)newContact;
- (void)contactAdded:(ChatUser *)contact;
- (void)contactRemoved:(ChatUser *)contact;
- (void)contactImageChanged:(ChatUser *)contact;
@end

