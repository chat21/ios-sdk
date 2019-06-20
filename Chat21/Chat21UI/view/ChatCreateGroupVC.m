//
//  ChatCreateGroupVC.m
//
//  Created by Andrea Sponziello on 25/03/16.
//

#import "ChatCreateGroupVC.h"
#import "ChatSelectGroupMembersLocal.h"
#import "ChatUtil.h"
#import "ChatLocal.h"
#import "ChatImageUtil.h"

@implementation ChatCreateGroupVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initUI];
}

-(void)initUI {
    self.title = self.navigationItem.title = [ChatLocal translate:@"new group"];
    self.addPhotoLabelOverloaded.text = [ChatLocal translate:@"Add Photo"];
    self.messageLabel.text = [ChatLocal translate:@"create group info message"];
    self.groupNameTextField.placeholder = [ChatLocal translate:@"Group name placeholder"];
    self.nextButton.title = [ChatLocal translate:@"next"];
    self.cancelButton.title = [ChatLocal translate:@"cancel"];
    [self.groupNameTextField becomeFirstResponder];
    
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [self addControlChangeTextField:self.groupNameTextField];
    
    // group image
    UITapGestureRecognizer *tapImageView = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapProfilePhoto:)];
    UITapGestureRecognizer *tapLabelView = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapProfilePhoto:)];
    [self.groupImageView addGestureRecognizer:tapImageView];
    [self.addPhotoLabelOverloaded addGestureRecognizer:tapLabelView];
    self.addPhotoLabelOverloaded.userInteractionEnabled = YES;
    self.groupImageView.userInteractionEnabled = YES;
}

-(void)setupProfilePhoto:(UIImage *)image {
    self.addPhotoLabelOverloaded.hidden = YES;
    self.groupImageView.image = [ChatImageUtil circleImage:self.scaledImage];
}

-(void)removeProfilePhoto {
    self.scaledImage = nil;
    self.addPhotoLabelOverloaded.hidden = NO;
    self.groupImageView.image = nil;
}

-(void)tapProfilePhoto:(UITapGestureRecognizer *)gestureRecognizer {
    UIAlertController * alert =   [UIAlertController
                                   alertControllerWithTitle:nil
                                   message:[ChatLocal translate:@"Change Profile Photo"]
                                   preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction* delete = [UIAlertAction
                             actionWithTitle:[ChatLocal translate:@"Remove Photo"]
                             style:UIAlertActionStyleDestructive
                             handler:^(UIAlertAction * action)
                             {
                                 [self removeProfilePhoto];
                             }];
    
    UIAlertAction* photo = [UIAlertAction
                            actionWithTitle:[ChatLocal translate:@"Photo"]
                            style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction * action)
                            {
                                [self takePhoto];
                            }];
    UIAlertAction* photo_from_library = [UIAlertAction
                                         actionWithTitle:[ChatLocal translate:@"Photo from library"]
                                         style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction * action)
                                         {
                                             [self chooseExisting];
                                         }];
    UIAlertAction* cancel = [UIAlertAction
                             actionWithTitle:[ChatLocal translate:@"Cancel"]
                             style:UIAlertActionStyleCancel
                             handler:^(UIAlertAction * action)
                             {
                                 NSLog(@"cancel");
                             }];
    if (self.scaledImage != nil) {
        [alert addAction:delete];
    }
    [alert addAction:photo];
    [alert addAction:photo_from_library];
    [alert addAction:cancel];
    UIPopoverPresentationController *popPresenter = [alert
                                                     popoverPresentationController];
    UIView *view = gestureRecognizer.view;
    popPresenter.sourceView = view;
    popPresenter.sourceRect = view.bounds;
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)nextAction:(id)sender {
    [self performSegueWithIdentifier:@"AddMembers" sender:self];
}

- (IBAction)cancelAction:(id)sender {
    [self.view endEditing:YES];
//    [self.modalCallerDelegate setupViewController:self didCancelSetupWithInfo:nil];
    if (self.completionCallback) {
        [self dismissViewControllerAnimated:YES completion:^{
            self.completionCallback(nil, YES);
        }];
    }
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"AddMembers"]) {
        ChatSelectGroupMembersLocal *vc = (ChatSelectGroupMembersLocal *)[segue destinationViewController];
        NSString *text = [self.groupNameTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        vc.groupName = text;
        vc.profileImage = self.scaledImage;
        vc.completionCallback = self.completionCallback;
    }
}

-(void)addControlChangeTextField:(UITextField *)textField
{
    [textField addTarget:self
                  action:@selector(textFieldDidChange:)
        forControlEvents:UIControlEventEditingChanged];
}

-(void)textFieldDidChange:(UITextField *)textField {
    NSString *text = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([text length] > 0) {
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }
    else {
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }
}

// **************************************************
// **************** TAKE PHOTO SECTION **************
// **************************************************

- (void)takePhoto {
    //    NSLog(@"taking photo with user %@...", self.applicationContext.loggedUser);
    if (self.imagePickerController == nil) {
        [self initializeCamera];
    }
    [self presentViewController:self.imagePickerController animated:YES completion:^{}];
}

- (void)chooseExisting {
    NSLog(@"choose existing...");
    if (self.photoLibraryController == nil) {
        [self initializePhotoLibrary];
    }
    [self presentViewController:self.photoLibraryController animated:YES completion:nil];
}

-(void)initializeCamera {
    NSLog(@"cinitializeCamera...");
    self.imagePickerController = [[UIImagePickerController alloc] init];
    self.imagePickerController.delegate = self;
    self.imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    self.imagePickerController.allowsEditing = YES;
}

-(void)initializePhotoLibrary {
    NSLog(@"initializePhotoLibrary...");
    self.photoLibraryController = [[UIImagePickerController alloc] init];
    self.photoLibraryController.delegate = self;
    self.photoLibraryController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;// SavedPhotosAlbum;
    self.photoLibraryController.allowsEditing = YES;
}

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    // TODO apri showImagePreview
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self afterPickerCompletion:picker withInfo:info];
}

-(void)afterPickerCompletion:(UIImagePickerController *)picker withInfo:(NSDictionary *)info {
    UIImage *bigImage = [info objectForKey:@"UIImagePickerControllerEditedImage"];
    NSURL *local_image_url = [info objectForKey:@"UIImagePickerControllerImageURL"];
    NSString *image_original_file_name = [local_image_url lastPathComponent];
    NSLog(@"image_original_file_name: %@", image_original_file_name);
    self.scaledImage = bigImage;
    NSLog(@"image: %@", self.scaledImage);
    self.scaledImage = [ChatImageUtil adjustEXIF:self.scaledImage];
    self.scaledImage = [ChatImageUtil scaleImage:self.scaledImage toSize:CGSizeMake(1200, 1200)];
    [self setupProfilePhoto:self.scaledImage];
    //    [self performSegueWithIdentifier:@"imagePreview" sender:nil];
}

// **************************************************
// *************** END PHOTO SECTION ****************
// **************************************************

@end
