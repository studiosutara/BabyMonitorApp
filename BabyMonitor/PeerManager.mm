//  PeerManager.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/30/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.


#import  "PeerManager.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#import  "Utilities.h"
#import "DDLog.h"
const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation PeerManager

@synthesize mPeerManagerServer;
@synthesize mNetServiceBrowser;
@synthesize mPeerManagerDelegate;
@synthesize mCurrentPeerHostName;
@synthesize mCurrentlyConnectedPeer;

#pragma mark PeerManagerServer

-(id) init
{
 //   DDLogInfo(@"\nPeerManager: init...");
    return self;
}

-(void) dealloc
{
    //[mPeerPickerView release];
  //  DDLogInfo(@"\nPeerManager: deallocing PeerManager");
}

- (void) _showAlert:(NSString *)title
{
	/*UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title 
                                                        message:@"Check your networking configuration." 
                                                       delegate:self 
                                              cancelButtonTitle:@"OK" 
                                              otherButtonTitles:nil];
	[alertView show];*/
}

-(BMErrorCode) checkConnectionWithPeer
{
    BMErrorCode error = BM_ERROR_NONE;
    
    return error;
}

-(bool) isPeerOnline
{
    return TRUE;
    
    if(![mPeersArray count] || !self.mCurrentPeerHostName)
        return FALSE;
    
    int index = [mPeersArray indexOfObject:mCurrentPeerHostName];
   
    if(index == NSNotFound)
        return FALSE;
    else 
        return TRUE;
}

- (void) presentPicker 
{
	//if (!mPeerPickerView.superview) 
    {
        //add the subview here, maybe call a delegate of BMVC to add the subview
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"TimeToPresentPicker"
                                                            object:self];
	}
}

//debug function
-(void) start
{
    mPeerManagerServer = [[PeerManagerServer alloc] init];

	NSError *error = nil;
	if(mPeerManagerServer == nil || ![mPeerManagerServer start:&error]) 
    {
		if (error == nil) 
        {
			DDLogInfo(@"\nFailed creating server: Server instance is nil");
		} 
        else 
        {
            DDLogInfo(@"\nFailed creating server: %@", error);
		}
        
		[self _showAlert:@"\nFailed creating server"];
		return;
	}
    
    mPeersArray = [[NSMutableArray alloc] init];
	
	//Start advertising to clients, passing nil for the name to tell Bonjour to pick use default name
//	if(![mPeerManagerServer enableBonjourWithDomain:@"local" 
//                                applicationProtocol:[Utilities getBonjourType] name:nil]) 
//    {
//		[self _showAlert:@"Failed advertising server"];
//		return;
//	}
    
    NSNetServiceBrowser *aNetServiceBrowser = [[NSNetServiceBrowser alloc] init];
	if(!aNetServiceBrowser) 
    {
        DDLogInfo(@"\nPeerManager: The NSNetServiceBrowser couldn't be allocated and initialized.");
		return;
	}
    
	aNetServiceBrowser.delegate = self;
	self.mNetServiceBrowser = aNetServiceBrowser;
	[self.mNetServiceBrowser searchForServicesOfType:[Utilities getBonjourType] inDomain:@"local"];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser 
         didRemoveService:(NSNetService *)service 
               moreComing:(BOOL)moreComing 
{
//	DDLogInfo(@"\nPeerManager:netServiceBrowser didRemoveService Service name %@ hostname=%@",
//          service.name, mCurrentPeerHostName);
    
	if([service.name caseInsensitiveCompare:mCurrentPeerHostName] == NSOrderedSame)
    {
      //  DDLogInfo(@"\nPeerManager: Peer service  has been removed!!");
        if (self.mPeerManagerDelegate && 
            [self.mPeerManagerDelegate respondsToSelector:@selector(peerWentOffline:)])
        {
            DDLogInfo(@"\nPeerManager: calling delegate for peerWentOffline");
            [self.mPeerManagerDelegate peerWentOffline:service];
        }
    }
    
    for(int i= 0;i<[mPeersArray count]; i++)
    {
        [mPeersArray removeObject:service.name];
    }
}	

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser 
           didFindService:(NSNetService *)service 
               moreComing:(BOOL)moreComing 
{
   // DDLogInfo(@"\nPeerManager:didFindService: Service name %@", service.name);
    
    [mPeersArray addObject:service.name];
    
    if([service.name caseInsensitiveCompare:mCurrentPeerHostName] == NSOrderedSame)
    {
        if(self.mPeerManagerDelegate &&
           [self.mPeerManagerDelegate respondsToSelector:@selector(peerCameOnline:)])
        {
            [self.mPeerManagerDelegate peerCameOnline:service];
        }
    }
}	

#pragma mark -



@end

