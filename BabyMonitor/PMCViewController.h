//
//  PMCViewController.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 6/22/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PeerManagerServer.h"
#import "BMUtility.h"

@class PMCViewController;

@protocol PMCStatusDelegate <NSObject>

//It is ending if it is not starting
-(void) PMCIslookingForPeers:(bool) isStarting numOfPeersFound:(short)num withPeerName:(NSString*)peerName;
-(void) PMCIsConnectingWithPeer:(NSString*)currentlyConnectingToPeer;
-(void) PMCConnectionWithPeerEndedWithError:(BMErrorCode) error peerName:(NSString*) str;
-(void) tryConnectionAfterResolve:(NSNetService *)netService;
@end


@interface PMCViewController: NSObject <NSNetServiceDelegate, NSNetServiceBrowserDelegate>
{
@private
    __weak id<PMCStatusDelegate>  mStatusDelegate;
	NSString*                     _searchingForServicesString;
	NSString*                     _ownName;
	NSNetService*                 _ownEntry;
	NSMutableArray*               _services;
	NSNetServiceBrowser*          _netServiceBrowser;
	NSNetService*                 _currentResolve;
	NSTimer*                      _timer;
	BOOL                          _needsActivityIndicator;
	BOOL                          _initialWaitOver;
}

@property (nonatomic, weak) id<PMCStatusDelegate> mStatusDelegate;
@property (nonatomic, strong) NSString* searchingForServicesString;
@property (nonatomic, strong) NSString* ownName;

-(void) stopSearchingForServices;
- (BOOL)searchForServicesOfType:(NSString *)type inDomain:(NSString *)domain;
-(BMErrorCode) tryConnectingWithPeer;

@end
