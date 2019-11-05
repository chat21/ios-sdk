//
//  ChatSelectUserLocalVC.h
//
//  Created by Andrea Sponziello on 13/09/2017.
//  Copyright © 2017 Frontiere21. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ChatSynchDelegate.h"
#import "ChatSelectContactProtocol.h"

@class ChatImageCache;
@class ChatGroup;
@class ChatUser;
@class ChatDiskImageCache;
@class ChatUserCellConfigurator;

@interface ChatSelectUserLocalVC : UIViewController <UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource, ChatSynchDelegate, ChatSelectContactProtocol>

@property (strong, nonatomic) ChatUser * _Nullable userSelected;
@property (strong, nonatomic) NSArray<ChatUser *> * _Nullable users;
//@property (nonatomic, copy) void (^completionCallback)(ChatUser *contact, BOOL canceled);
@property (nonatomic, copy) void (^ _Nullable completionCallback)( ChatUser * _Nullable contact, BOOL canceled);
@property (weak, nonatomic) IBOutlet UITableView * _Nullable tableView;
@property (weak, nonatomic) IBOutlet UISearchBar * _Nullable searchBar;
@property (strong, nonatomic) NSString * _Nullable searchBarPlaceholder;
@property (strong, nonatomic) NSString * _Nullable textToSearch;
@property (strong, nonatomic) NSTimer * _Nullable searchTimer;
@property (strong, nonatomic) NSString * _Nullable lastUsersTextSearch;
@property (strong, nonatomic) ChatGroup * _Nullable group;
@property (assign, nonatomic) BOOL synchronizing;
@property (strong, nonatomic) UIActivityIndicatorView * _Nullable activityIndicator;
@property (strong, nonatomic) ChatUserCellConfigurator * _Nullable cellConfigurator;
@property (weak, nonatomic) IBOutlet UIBarButtonItem * _Nullable cancelButton;

//-(void)networkError;
- (IBAction)CancelAction:(id _Nonnull )sender;

@end

