//
//  PeerManager.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/30/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PMCViewController.h"
#import "PeerManagerServer.h"
#import "Utilities.h"
#import "BMUtility.h"

@protocol PeerManagerDelegate <NSObject>
@required
// This method will be invoked when the user selects one of the service instances from the Peerclients list
//and once the instance is resolved. we ask the statemachine to try and do an initial handshake with that client 
- (BMErrorCode) peerCameOnline:(NSNetService*) netService;
- (BMErrorCode) peerWentOffline:(NSNetService*) netService;
@end

@interface PeerManager : NSObject <NSNetServiceBrowserDelegate>
{
    __weak id <PeerManagerDelegate>     mPeerManagerDelegate;
    
    NSMutableArray*                     mPeersArray;
	PeerManagerServer*                  mPeerManagerServer;
    
    NSNetService*                       mCurrentlyConnectedPeer;
    
    NSString*                           mCurrentPeerHostName;
    
    //we need this to keep track of the peer coming and going offline
    NSNetServiceBrowser*   mNetServiceBrowser;
}

-(void) start; 
-(BMErrorCode) checkConnectionWithPeer;
-(bool) isPeerOnline;

@property (nonatomic) PeerManagerServer*               mPeerManagerServer;
@property (nonatomic, weak) id<PeerManagerDelegate>    mPeerManagerDelegate;
@property (nonatomic, strong) NSNetServiceBrowser*     mNetServiceBrowser;
@property (nonatomic, strong) NSString*                mCurrentPeerHostName;
@property (nonatomic, strong) NSNetService*            mCurrentlyConnectedPeer;
@end
