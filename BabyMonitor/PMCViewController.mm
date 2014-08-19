//
//  PMCViewController.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 6/22/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "PMCViewController.h"
#import "DDLog.h"
const int ddLogLevel = LOG_LEVEL_VERBOSE;

#define kProgressIndicatorSize 20.0


@interface NSNetService (BrowserViewControllerAdditions)
- (NSComparisonResult) localizedCaseInsensitiveCompareByName:(NSNetService *)aService;
@end

@implementation NSNetService (BrowserViewControllerAdditions)
- (NSComparisonResult) localizedCaseInsensitiveCompareByName:(NSNetService *)aService 
{
	return [[self name] localizedCaseInsensitiveCompare:[aService name]];
}
@end

@interface PMCViewController()
@property (nonatomic, readwrite) NSNetService *ownEntry;
@property (nonatomic, readwrite) NSMutableArray *services;
@property (nonatomic, readwrite) NSNetServiceBrowser *netServiceBrowser;
@property (nonatomic, readwrite) NSNetService *currentResolve;
@property (nonatomic, readwrite) NSTimer *timer;
@property (nonatomic) BOOL needsActivityIndicator;
@property (nonatomic) BOOL initialWaitOver;
@property (nonatomic, strong) NSTimer* mPeerSearchTimer;
@end


@implementation PMCViewController

@synthesize mStatusDelegate;
@synthesize ownEntry = _ownEntry;
@synthesize currentResolve = _currentResolve;
@synthesize netServiceBrowser = _netServiceBrowser;
@synthesize services = _services;
@synthesize needsActivityIndicator = _needsActivityIndicator;
@dynamic timer;
@synthesize initialWaitOver = _initialWaitOver;


- (id)init
{
    
//    // Make sure we have a chance to discover devices before showing the user that nothing was found (yet)
//    [NSTimer scheduledTimerWithTimeInterval:1.0 
//                                     target:self 
//                                   selector:@selector(initialWaitOver:) 
//                                   userInfo:nil 
//                                    repeats:NO];
    return self;
}

- (NSString *)searchingForServicesString 
{
    //(@"searchingForServicesString");
	return _searchingForServicesString;
}

// Holds the string that's displayed in the table view during service discovery.
- (void)setSearchingForServicesString:(NSString *)searchingForServicesString 
{
    //(@"setSearchingForServicesString");
    
	if (_searchingForServicesString != searchingForServicesString) 
    {
		_searchingForServicesString = [searchingForServicesString copy];
	}
}

- (NSString *)ownName 
{
	return _ownName;
}

// Holds the string that's displayed in the table view during service discovery.
- (void)setOwnName:(NSString *)name 
{
	if (_ownName != name) 
    {
		_ownName = [name copy];
		
		if (self.ownEntry)
			[self.services addObject:self.ownEntry];
		
		NSNetService* service;
		
		for (service in self.services) 
        {
			if ([service.name isEqual:name]) 
            {
				self.ownEntry = service;
				[_services removeObject:service];
				break;
			}
		}
        
	}
}

// Creates an NSNetServiceBrowser that searches for services of a particular type in a particular domain.
// If a service is currently being resolved, stop resolving it and stop the service browser from
// discovering other services.
- (BOOL)searchForServicesOfType:(NSString *)type inDomain:(NSString *)domain 
{
    _services = [[NSMutableArray alloc] init];

	//(@"searchForServicesOfType %@ inDomain %@", type, domain);
	[self stopCurrentResolve];
	[self.netServiceBrowser stop];
	[self.services removeAllObjects];
    
	NSNetServiceBrowser *aNetServiceBrowser = [[NSNetServiceBrowser alloc] init];
	if(!aNetServiceBrowser) 
    {
        DDLogInfo(@"\nThe NSNetServiceBrowser couldn't be allocated and initialized.");
		return NO;
	}
    
	aNetServiceBrowser.delegate = self;
	self.netServiceBrowser = aNetServiceBrowser;
    
    if(self.mStatusDelegate && 
       [self.mStatusDelegate 
        respondsToSelector:@selector(PMCIslookingForPeers: numOfPeersFound: withPeerName:)])
    {
        [self.mStatusDelegate PMCIslookingForPeers:YES 
                                   numOfPeersFound:0 withPeerName:nil];
    }

    
	[self.netServiceBrowser searchForServicesOfType:type inDomain:domain];
    self.mPeerSearchTimer = [NSTimer scheduledTimerWithTimeInterval:2
                                     target:self
                                   selector:@selector(searchTimerFired)
                                   userInfo:nil
                                    repeats:NO];
	return YES;
}

-(void) stopSearchingForServices
{
    [self.netServiceBrowser stop];
}

-(void) searchTimerFired
{
    if(self.mStatusDelegate &&
       [self.mStatusDelegate
        respondsToSelector:@selector(PMCIslookingForPeers: numOfPeersFound: withPeerName:)])
    {
        int count = [self.services count];
        NSString* peer = nil;
        
        if(count)
            peer = [[self.services objectAtIndex:count-1] name];
        
        NSLog(@"searchTimerFired PMCIslookingForPeers");

        [self.mStatusDelegate PMCIslookingForPeers:NO
                                   numOfPeersFound:count
                                      withPeerName: peer];
    }
}

- (NSTimer *)timer
{
	return _timer;
}

// When this is called, invalidate the existing timer before releasing it.
- (void)setTimer:(NSTimer *)newTimer 
{
	[_timer invalidate];
	_timer = newTimer;
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser 
         didRemoveService:(NSNetService *)service 
               moreComing:(BOOL)moreComing 
{
	// If a service went away, stop resolving it if it's currently being resolved,
	// remove it from the list and update the table view if no more events are queued.
	DDLogInfo(@"\nPeerManagerClient:netServiceBrowser didRemoveService");
	if (self.currentResolve && [service isEqual:self.currentResolve]) 
    {
		[self stopCurrentResolve];
	}
	[self.services removeObject:service];
	if (self.ownEntry == service)
    {
		self.ownEntry = nil;
    }
	
	// If moreComing is NO, it means that there are no more messages in the queue from the Bonjour daemon, so we should update the UI.
	// When moreComing is set, we don't update the UI so that it doesn't 'flash'.
	if (!moreComing) 
    {        
       // DDLogInfo(@"\nPMCCOntroller: Done searching for services");
        int count = [self.services count];
        NSString* peer = nil;
        
        if(count)
            peer = [[self.services objectAtIndex:count-1] name];
        
                NSLog(@"didRemoveService PMCIslookingForPeers");
        [self.mStatusDelegate PMCIslookingForPeers:NO
                                   numOfPeersFound:count
                                      withPeerName: peer];
        
        [self.mPeerSearchTimer invalidate];
	}
}	

- (void)stopCurrentResolve 
{
    self.timer = nil;
    
    [self.currentResolve stop];
    self.currentResolve = nil;
}


- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser 
           didFindService:(NSNetService *)service moreComing:(BOOL)moreComing 
{
	// If a service came online, add it to the list and update the table view if no more events are queued.
//    DDLogInfo(@"\nPeerManagerClient didFindService: Service name %@ own name:%@", service.name, self.ownName);
	if ([service.name isEqual:[[UIDevice currentDevice] name]])
    {
		self.ownEntry = service;
    }
	else
		[self.services addObject:service];
    
	// If moreComing is NO, it means that there are no more messages in the queue from the Bonjour daemon, so we should update the UI.
	// When moreComing is set, we don't update the UI so that it doesn't 'flash'.
	if (!moreComing) 
    {
        int count = [self.services count];
        NSString* peer = nil;
        
        if(count)
            peer = [[self.services objectAtIndex:count-1] name];
        
        NSLog(@"didFindService PMCIslookingForPeers");
        [self.mStatusDelegate PMCIslookingForPeers:NO
                                   numOfPeersFound:count
                                      withPeerName: peer];
        [self.mPeerSearchTimer invalidate];
	}
}

// This should never be called, since we resolve with a timeout of 0.0, which means indefinite
- (void)netService:(NSNetService *)sender 
     didNotResolve:(NSDictionary *)errorDict 
{
 //   DDLogInfo(@"\nPMCController: Unable to resolve address");

	[self stopCurrentResolve];
    
    if(self.mStatusDelegate && 
       [self.mStatusDelegate respondsToSelector:@selector(PMCConnectionWithPeerEndedWithError:peerName:)])
    {
        [self.mStatusDelegate PMCConnectionWithPeerEndedWithError:BM_ERROR_FAIL 
                                                         peerName:[sender name]];
    }
    
}

- (void)netServiceDidResolveAddress:(NSNetService *)service 
{
  //  DDLogInfo(@"\nPMCController Resolved address:");
    //printService(service);
	assert(service == self.currentResolve);
	
    // DDLogInfo(@"\n%@",[service description]);
	[self stopCurrentResolve];
    
    if (self.mStatusDelegate && 
        [self.mStatusDelegate respondsToSelector:@selector(tryConnectionAfterResolve:)]) 
    {
        DDLogInfo(@"\nclient Calling PM delegate");
        [self.mStatusDelegate tryConnectionAfterResolve:service];
    }
    else
        DDLogInfo(@"\nclient delegate not implemented");
}

-(BMErrorCode) tryConnectingWithPeer
{
    if(![self.services count])
    {
        return BM_ERROR_NONE;
    }
    // Then set the current resolve to the service corresponding to the tapped cell
    int num = [self.services count] -1 ;
	self.currentResolve = [self.services objectAtIndex: num];
	[self.currentResolve setDelegate:self];
    
    // Attempt to resolve the service. A value of 0.0 sets an unlimited time to resolve it. The user can
	// choose to cancel the resolve by selecting another service in the table view.
//    DDLogInfo(@"\nPMVC: Attempting to resolve name:%@ hostname:%@", [self.currentResolve name], [self.currentResolve hostName]);
//    DDLogInfo(@"\nPMVC: Netservice is %@", [self.currentResolve description]);
    
	[self.currentResolve resolveWithTimeout:4];
    
    if(self.mStatusDelegate && 
       [self.mStatusDelegate respondsToSelector:@selector(PMCIsConnectingWithPeer:)])
    {
        [self.mStatusDelegate PMCIsConnectingWithPeer:[self.currentResolve name]];
    }

    return BM_ERROR_NONE;
}

@end
