//
//  FBService.h
//  ChattAR 
//
//  Created by QuickBlox developers on 07.05.12.
//  Copyright (c) 2012 QuickBlox. All rights reserved.
//

@class XMPPStream;

@interface FBService : NSObject
{
    //NSTimer     *presenceTimer;
	XMPPStream	*xmppStream;
}
@property (nonatomic, strong) NSTimer *presenceTimer;
@property (strong, nonatomic) FBSession *session;

+ (instancetype)shared;


#pragma mark -
#pragma mark Facebook Requests

- (void) userProfileWithResultBlock:(FBResultBlock)resultBlock;
- (void) userFriendsUsingBlock:(FBResultBlock)resultBlock;
- (void) userProfileWithID:(NSString *)userID withBlock:(FBResultBlock)resultBlock;
- (void)usersProfilesWithIDs:(NSArray *)userIDs resultBlock:(FBResultBlock)resultBlock;


#pragma mark -
#pragma mark Messages

- (void)sendMessage:(NSString *)messageText toUserWithID:(NSString *)userID;


#pragma mark -
#pragma mark Post to Feed

- (void)publishMessageToFeed:(NSString *)message;


#pragma mark -
#pragma mark Options

+ (NSMutableDictionary *)findFBConversationWithFriend:(NSMutableDictionary *)aFriend;
- (NSMutableArray *)gettingAllIDsOfFacebookUsers:(NSMutableArray *)facebookUsers;
- (NSMutableArray *)putQuickbBloxIDsToFacebookUsers:(NSMutableArray *)facebookUsers fromQuickbloxUsers:(NSArray *)quickbloxUsers ;


#pragma mark -
#pragma mark Loading and handling

- (void)loadAndHandleDataAboutMeAndMyFriends;
- (NSMutableDictionary *)handleFacebookHistoryConversation:(NSMutableArray *)conversation;


#pragma mark -
#pragma mark XMPP Chat

- (void) logInChat;
- (void) logOutChat;
- (void) sendMessage:(NSString*)textMessage toFacebookWithFriendID:(NSString*)friendID;
- (void) inboxMessagesWithBlock:(FBResultBlock)resultBlock;

@end