//
//  ChatRoomViewController.m
//  ChattAR
//
//  Created by Igor Alefirenko on 11/09/2013.
//  Copyright (c) 2013 QuickBlox. All rights reserved.
//

#import "ChatRoomViewController.h"
#import "ChatRoomCell.h"
#import "ChatRoomStorage.h"
#import "QuotedChatRoomCell.h"
#import "FBStorage.h"
#import "FBService.h"
#import "QBService.h"
#import "QBStorage.h"
#import "DetailDialogsViewController.h"
#import "ProfileViewController.h"
#import "ChatRoomDataSource.h"
#import "MBProgressHUD.h"


@interface ChatRoomViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, QBChatDelegate, QBActionStatusDelegate, CLLocationManagerDelegate, UIActionSheetDelegate, SASlideMenuDelegate>

@property (strong, nonatomic) ChatRoomDataSource *chatRoomDataSource;
@property (strong, nonatomic) UIActivityIndicatorView *indicatorView;
@property (strong, nonatomic) IBOutlet UIButton *backButton;
@property (strong, nonatomic) NSMutableDictionary *quote;
@property (strong, nonatomic) QBChatRoom *currentRoom;
@property (strong, nonatomic) IBOutlet UIView *inputTextView;
@property (strong, nonatomic) IBOutlet UITextField *inputMessageField;
@property (strong, nonatomic) IBOutlet UIButton *sendButton;
@property (strong, nonatomic) NSMutableArray *chatHistory;
@property (strong, nonatomic) NSIndexPath *cellPath;
@property (strong, nonatomic) NSMutableDictionary *dialogTo;
@property (strong, nonatomic) MBProgressHUD *progressHUD;

@property CGFloat cellSize;

- (IBAction)textEditDone:(id)sender;
- (IBAction)backToRooms:(id)sender;
- (IBAction)sendMessageButton:(id)sender;

@end

@implementation ChatRoomViewController
@synthesize cellPath;
@synthesize quote;


#pragma mark LifeCycle


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.chatRoomDataSource = [[ChatRoomDataSource alloc] init];
    self.chatRoomTable.dataSource = self.chatRoomDataSource;
    self.chatRoomDataSource.chatHistory = self.chatHistory;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(joinedRoom) name:CAChatRoomDidEnterNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageReceived) name:CAChatRoomDidReceiveOrSendMessageNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recordPublished:) name:CARoomDidPublishedToFacebookNotification object:nil];
    //[self setSpinner];
    _progressHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [self configureInputTextViewLayer];
    NSString *roomName = [_currentChatRoom.fields objectForKey:kName];
    self.title = roomName;
    [self creatingOrJoiningRoom];
}

- (void)setSpinner
{
    if (!self.indicatorView) {
        self.indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        self.indicatorView.frame = CGRectMake(self.chatRoomTable.frame.size.width/2 - 10, self.chatRoomTable.frame.size.height/2 -10, 20 , 20);
        [self.indicatorView hidesWhenStopped];
        self.indicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
        self.indicatorView.color = [UIColor blackColor];
        [self.view addSubview:self.indicatorView];
    }
    [self.indicatorView startAnimating];
}

- (void)configureInputTextViewLayer
{
    self.inputTextView.layer.shadowColor = [[UIColor blackColor] CGColor];
    self.inputTextView.layer.shadowRadius = 7.0f;
    self.inputTextView.layer.masksToBounds = NO;
    self.inputTextView.layer.shadowOffset = CGSizeMake(0.0f, 4.0f);
    self.inputTextView.layer.shadowOpacity = 1.0f;
    self.inputTextView.layer.borderWidth = 0.1f;
    
    // button corner-radius
    self.sendButton.layer.cornerRadius = 5.0f;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}


#pragma mark -
#pragma mark Table View Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Identifier"];
    return cell;
}

#pragma mark -
#pragma mark Table View Delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat cellHeight;
    NSString *chatString = [[_chatHistory objectAtIndex:indexPath.row] text];
    NSData *data = [chatString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    NSString *currentMessage = [dictionary objectForKey:kMessage];
    if ([dictionary objectForKey:kQuote] == nil) {
       cellHeight = [ChatRoomCell configureHeightForCellWithMessage:currentMessage];
    } else {
        cellHeight = [QuotedChatRoomCell configureHeightForCellWithDictionary:currentMessage];
    }
    return cellHeight;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.chatRoomTable deselectRowAtIndexPath:indexPath animated:YES];
    QBChatMessage *chatMsg = [_chatHistory objectAtIndex:[indexPath row]];
    NSMutableDictionary *messageData = [[QBService defaultService] unarchiveMessageData:chatMsg.text];
    NSString *userID = [messageData objectForKey:kId];
    if (![userID isEqual:[[FBStorage shared].me objectForKey:kId]]) {
        cellPath = indexPath;
        NSString *title = [[NSString alloc] initWithFormat:@"What do you want?"];
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:title delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Reply", @"Private message", @"View Profile", nil];
        [actionSheet showInView:self.view];
    }
}


#pragma mark -
#pragma mark UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex) {
        case 0:
        {
            NSLog(@"REPLY");
            QBChatMessage *msg = [_chatHistory objectAtIndex:[cellPath row]];
            
            NSString *string = msg.text;
            cellPath = nil;
            // JSON parsing
            NSDictionary *jsonDict = [[QBService defaultService] unarchiveMessageData:string];
            
            //saving user...
            if (quote == nil) {
                quote = [[NSMutableDictionary alloc] init];
            }
            NSString *time = [[Utilites shared].dateFormatter stringFromDate:msg.datetime];
            
            [quote setValue:[jsonDict objectForKey:kPhoto] forKey:kPhoto];
            [quote setValue:[jsonDict objectForKey:kUserName] forKey:kUserName];
            [quote setValue:[jsonDict objectForKey:kMessage] forKey:kMessage];
            [quote setValue:time forKey:kDateTime];
            
            [self.inputMessageField becomeFirstResponder];
            break;
        }
        case 1:
        {
            // Dialogs View Controller:
            QBChatMessage *msg = [_chatHistory objectAtIndex:[cellPath row]];
            NSMutableDictionary *currentUser = [self userWithMessage:msg];
            if ([[FBStorage shared] isFacebookFriend:currentUser]) {
                NSMutableDictionary *dialog = [FBService findFBConversationWithFriend:currentUser];
                self.dialogTo = dialog;
            } else {
                // finding QB conversation:
                NSMutableDictionary *dialog = [[QBService defaultService] findConversationToUserWithMessage:msg];
                    self.dialogTo = dialog;
            }
            [self performSegueWithIdentifier:kChatToDialogSegueIdentifier sender:currentUser];
            break;
        }
        case 2:
        {
            // Profile View Controller:
            QBChatMessage *msg = [_chatHistory objectAtIndex:[cellPath row]];
            NSMutableDictionary *currentFriend = [self userWithMessage:msg];
            [self performSegueWithIdentifier:kChatToProfileSegieIdentifier sender:currentFriend];
            break;
        }
    }
}

- (NSMutableDictionary *)userWithMessage:(QBChatMessage *)message {
    NSMutableDictionary *currentFriend = [[FBStorage shared] findUserWithMessage:message];
    if (currentFriend == nil) {
        //creating FBUser(No Friend):
        NSMutableDictionary *messageData = [[QBService defaultService] unarchiveMessageData:message.text];
        currentFriend = [[NSMutableDictionary alloc] init];
        [currentFriend setObject:[messageData objectForKey:kUserName] forKey:kName];
        NSString *urlString = [[NSString alloc] initWithFormat:@"https://graph.facebook.com/%@/picture?access_token=%@", [messageData objectForKey:kId], [FBStorage shared].accessToken];
        [currentFriend setObject:urlString forKey:kPhoto];
        [currentFriend setObject:[messageData objectForKey:kId] forKey:kId];
        [currentFriend setObject:[messageData objectForKey:kQuickbloxID] forKey:kQuickbloxID];
        // caching created user:
        [[QBStorage shared].otherUsers addObject:currentFriend];
    }
    return currentFriend;
}


#pragma mark -
#pragma mark ChatRoom

- (void)creatingOrJoiningRoom
{
    NSString *facebookID = [[FBStorage shared].me objectForKey:kId];
    NSString *roomName = [_currentChatRoom.fields objectForKey:kName];
    // saving room name to cache:
    [QBStorage shared].chatRoomName = roomName;
    // login to room:
    [[QBService defaultService] chatCreateOrJoinRoomWithName:roomName andNickName:facebookID];
}


#pragma mark -
#pragma mark Actions

// back button
- (IBAction)backToRooms:(id)sender
{
    [QBStorage shared].currentChatRoom = nil;
    [QBService defaultService].userIsJoinedChatRoom = NO;
    [[QBStorage shared].chatHistory removeAllObjects];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

// action message button
- (IBAction)sendMessageButton:(id)sender
{
    NSString *trimmedString = [self.inputMessageField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmedString isEqual:@""]) {
        //don't send
        [self.inputMessageField resignFirstResponder];
        return;
    }
        [[QBService defaultService] sendmessage:trimmedString toChatRoom:self.currentRoom quote:quote];
        self.inputMessageField.text = @"";
    [self.chatRoomTable reloadData];
    [self.inputMessageField resignFirstResponder];
}


#pragma mark -
#pragma mark Notifications

- (void)resetTableView {
    [self.chatRoomTable reloadData];
    if ([_chatHistory count] > 2) {
        [self.chatRoomTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:[_chatHistory count]-1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

- (void)joinedRoom {
    [Flurry logEvent:kFlurryEventRoomWasJoined withParameters:@{kFrom:self.controllerName}];
    self.currentRoom = [QBStorage shared].currentChatRoom;
    [[ChatRoomStorage shared] increaseRankOfRoom:self.currentChatRoom];
    [self.chatRoomTable reloadData];
    //[self.indicatorView stopAnimating];
     [_progressHUD performSelector:@selector(hide:) withObject:nil afterDelay:1.0];
}

- (void)messageReceived {
    self.chatHistory = [QBStorage shared].chatHistory;
    self.chatRoomDataSource.chatHistory = self.chatHistory;
    [self resetTableView];
    [NSObject cancelPreviousPerformRequestsWithTarget:_progressHUD selector:@selector(hide:) object:nil];
    [_progressHUD performSelector:@selector(hide:) withObject:nil afterDelay:1.0];
}

- (void)recordPublished:(NSNotification *)aNotification {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    NSError *error = aNotification.object;
    NSString *alertText;
    if (error) {
        alertText = [NSString stringWithFormat:
                     @"error: domain = %@, code = %d",
                     error.domain, error.code];
    } else {
        alertText = [NSString stringWithFormat:
                     @"Posted successfull"];
        [Flurry logEvent:kFlurryEventRoomWasSharedToFacebook];
    }
    // Show the result in an alert
    [[[UIAlertView alloc] initWithTitle:@"Result"
                                message:alertText
                               delegate:self
                      cancelButtonTitle:@"OK!"
                      otherButtonTitles:nil]
     show];
}


#pragma mark -
#pragma mark Show/Hide Keyboard

- (void)showKeyboard
{
    [UIView animateWithDuration:0.275 animations:^{
        self.inputTextView.transform = CGAffineTransformMakeTranslation(0, -215);
        self.chatRoomTable.transform = CGAffineTransformMakeTranslation(0, -215);
    }];
}

- (void)hideKeyboard
{
    [UIView animateWithDuration:0.275 animations:^{
        self.inputTextView.transform = CGAffineTransformIdentity;
        self.chatRoomTable.transform = CGAffineTransformIdentity;;
    }];
}


#pragma mark -
#pragma mark UITextField

- (IBAction)textEditDone:(id)sender
{
    [sender resignFirstResponder];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    [self showKeyboard];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    [self hideKeyboard];
}


#pragma mark -
#pragma mark Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:kChatToProfileSegieIdentifier]) {
        ((ProfileViewController *)segue.destinationViewController).controllerTitle = @"room";   // info for Flurry analytics
        ((ProfileViewController *)segue.destinationViewController).currentUser = sender;
        return;
    }
    ((DetailDialogsViewController *)segue.destinationViewController).opponent = sender;
    ((DetailDialogsViewController *)segue.destinationViewController).conversation = self.dialogTo;
    if ([[FBStorage shared] isFacebookFriend:sender]) {
        ((DetailDialogsViewController *)segue.destinationViewController).isChatWithFacebookFriend = YES;
        return;
    }
    ((DetailDialogsViewController *)segue.destinationViewController).isChatWithFacebookFriend = NO;
}


#pragma mark -
#pragma mark Sharing

- (IBAction)share:(id)sender
{
    //[self.indicatorView startAnimating];
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    NSString *initialText = [NSString stringWithFormat:@"Hi! I use ChattAR app - Chat in Augmented Reality. Join me in a cool chat room \"%@\"!  #chattar #facebook", [_currentChatRoom.fields objectForKey:kName]];
    
    // Ask for publish_actions permissions in context
    if ([FBSession.activeSession.permissions
         indexOfObject:@"publish_actions"] == NSNotFound) {
        // No permissions found in session, ask for it
        [FBSession.activeSession
         requestNewPublishPermissions:@[@"publish_actions"]
         defaultAudience:FBSessionDefaultAudienceFriends
         completionHandler:^(FBSession *session, NSError *error) {
             if (!error) {
                 // If permissions granted, publish the story
                 [[FBService shared] publishMessageToFeed:initialText];
             }
         }];
    } else {
        // If permissions present, publish the story
        [[FBService shared] publishMessageToFeed:initialText];
    }
}

@end