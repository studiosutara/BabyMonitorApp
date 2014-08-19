//
//  BabyMonitorAppDelegate.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/20/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#import "BabyMonitorAppDelegate.h"
#import "DDLog.h"
#import "DDASLLogger.h"
#import "DDTTYLogger.h"
#import "DDFileLogger.h"
#import "DDLog.h"
#import "HowItWorksScreenViewController.h"
#import "PersistentStorage.h"

const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation BabyMonitorAppDelegate


@synthesize window;
@synthesize mCurrentCallState;
@synthesize mMainCoordinator;

//static void callStateChanged()

-(void) callStateChanged:(NSString*) callState
{
    //NSLog(@"\nBMAppDelegate: callStateChanged!!!");
    
    if(callState == CTCallStateIncoming)
    {
        [mMainCoordinator handleAppWillGoToBackground:YES];
    }
    else if(callState == CTCallStateDisconnected)
    {
        [mMainCoordinator handleAppWillComeToForeground];
    }
}

-(void) loadAndInitializeMainMonitorView
{
    //NSLog(@"\nAppDelegate: loadAndInitializeMainMonitorView");
    
    [PersistentStorage markFirstLaunchAsDone];

    MainMonitorViewController* babyMonitorViewController =
    [[MainMonitorViewController alloc] initWithNibName:@"MainMonitorViewController" 
                                                bundle:nil];
    babyMonitorViewController.mDelegate = mMainCoordinator;
    mMainCoordinator.mStateMachine.mDelegate = mMainCoordinator;

    self.window.rootViewController = babyMonitorViewController;
    [self.window addSubview:babyMonitorViewController.view];
    mMainCoordinator.mMainMonitorViewController = babyMonitorViewController;
}

- (BOOL)application:(UIApplication *)application 
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //NSLog(@"\nAppDelegate:didFinishLaunchingWithOptions");
   
    [self addLogger];

    __weak BabyMonitorAppDelegate *appdel = self;
    
    mCallCenter = [[CTCallCenter alloc] init];
    
    __block MainViewControllerCoordinator* mainController = self.mMainCoordinator;
    mCallCenter.callEventHandler = ^(CTCall *call)
    {
        //NSLog(@"\n\nBMAppDelegate: call:%@\n\n", call.callState);
        if(call.callState == CTCallStateIncoming)
        {
            [mainController handleAppWillGoToBackground:YES];
        }
        
        appdel.mCurrentCallState = call.callState;
    };
    
     [self getStarted];
    
    [self.window makeKeyAndVisible];
    mCurrentCallState = nil;
    

    return TRUE;
}

-(bool) getStarted
{    
    //NSLog(@"\n AppDelegate: Getting STARTED");
    
    // Override point for customization after application launch.
    mMainCoordinator = [[MainViewControllerCoordinator alloc] initAndLaunchView:[PersistentStorage isFirstTimeLaunch]];
    
    if(!mMainCoordinator)
    {
        NSLog(@"\nAppDelegate: No MainViewControllerCoordinator, bailing out...!");
        return TRUE;
    }
    
    [mMainCoordinator startMainVCCoordinator];
    if([PersistentStorage isFirstTimeLaunch])
    {
        mLaunchController = [[LaunchViewController alloc] init];
        mLaunchController.mDelegate = self;
        
        self.window.rootViewController = mLaunchController;
        [window addSubview:mLaunchController.view];
        
        //we will receive all the delegate calls since we are launching for the first time
        //later on once the main screen is launched even once, the maincoordinator can be
        //the delegate
        self.mMainCoordinator.mStateMachine.mDelegate = self;
        self.mMainCoordinator.mStateMachine.mCurrentBabyMonitorMode = BABY_OR_TRANSMITTER_MODE;
        [self.mMainCoordinator.mStateMachine writeModeToPersistentStrorage];
    }
    else
    {
        //Set the alternate rootcontroller from the maincoordinator here
        [self loadAndInitializeMainMonitorView];
    }
    
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    
    [mMainCoordinator handleAppWillComeToForeground];
    
    //reset after we have read the state
    mCurrentCallState = nil;
    return TRUE;
}


- (void)applicationWillResignActive:(UIApplication *)application
{
    //NSLog(@"\nBM: applicationWillResignActive, state=%@\n", mCurrentCallState);

    bool isCallActive = NO;
    if(mCurrentCallState == CTCallStateIncoming)
        isCallActive = YES;
    
    [mMainCoordinator handleAppWillGoToBackground:isCallActive];
    
    //reset after we have read the state
    mCurrentCallState = nil;
    
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
   // NSLog(@"\nBM: applicationDidEnterBackground, Call State=%@\n", mCurrentCallState);
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    //NSLog(@"\nBM: applicationWillEnterForeground, state=%@\n", mCurrentCallState);
    
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    
    //NSLog(@"\nAppDelegate: current battery = %f", [[UIDevice currentDevice]  batteryLevel]);
    
    /*Called as part of the transition from the background to the inactive state; 
     here you can undo many of the changes made on entering the background.*/
}

-(void) addLogger
{
    //NSLog(@"\nAppDelegate: adding logger");
    //[DDLog addLogger:[DDASLLogger sharedInstance]];
[DDLog addLogger:[DDTTYLogger sharedInstance]];
    
    NSString* baseDocDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString* logDir = [NSString stringWithFormat:@"%@/logs",baseDocDir];
    DDLogFileManagerDefault* logFileManager = [[DDLogFileManagerDefault alloc ]initWithLogsDirectory:logDir];
    DDFileLogger* fileLogger = [[DDFileLogger alloc] initWithLogFileManager:logFileManager];
    //...other settings...
    fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
    fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
    
    [DDLog addLogger:fileLogger];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    //NSLog(@"\nBM: applicationDidBecomeActive, state=%@\n", mCurrentCallState);
    
    [mMainCoordinator handleAppWillComeToForeground];
    
    [[UIApplication sharedApplication] cancelAllLocalNotifications];

    //reset after we have read the state
    mCurrentCallState = nil;

    /*Restart any tasks that were paused (or not yet started) while the application was inactive.
     If the application was previously in the background, optionally refresh the user interface.*/
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    NSLog(@"\nBM: applicationWillTerminate, state=%@\n", mCurrentCallState);
       
    /*Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.*/
}

-(void) applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    NSLog(@"\nBM: applicationDidReceiveMemoryWarning");
    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:Nil 
                                                        message:@"applicationDidReceiveMemoryWarning" 
                                                       delegate:self 
                                              cancelButtonTitle:@"OK" 
                                              otherButtonTitles:nil];    
    [alertView show];
}

//If we are the ones getting this delegate request, then we must be connecting for the first time
//A peer is trying to connect with us
-(void) inComingConnectionRequestFrom:(NSString*) peerName
{
    //If it is incoming, then we might be on any of the following 3 screens
    //IntroScreen
    //mode selection
    //peer picker
    //grey out these
    
    //Disable user interaction on the current screen, whatever it may be
    //the main monitor view will not yet be launch at this time. If it is, then
    //we will not be the recipients of this message here.
    
    //pop up a modal view showing that we are busy connecting
//    InComingConnectionRequestViewController* icrViewController =
//    [[InComingConnectionRequestViewController alloc] initWithMode:ICR_INCOMING_MODE
//                                                  backgroundImage:[Utilities getScreenShotWithSize:self.window.bounds.size
//                                                                                          andLayer:self.window.layer]];
//    
//    [self.window.rootViewController.view addSubview:icrViewController.view];
    
    //then show the main monitor view that is ready to start monitoring
}

-(void) outgoingConnectionToPeerComplete:(NSString*) peerName
{
    [mSettingsViewController setPairingStatus:CURRENTLY_PAIRED andWithInfo:peerName];
}

-(void) connectionStatusChanged:(bool) isConnected withPeer:(NSString*)peerName isIncoming:(bool) incoming
{
    if(isConnected)
    {
        if(incoming)
        {
            [self incomingConnectionToPeerComplete:peerName];
        }
        else
        {
            [self outgoingConnectionToPeerComplete:peerName];
        }
    }
}

-(void) incomingConnectionToPeerComplete:(NSString*) peerName
{
    [NSTimer scheduledTimerWithTimeInterval:1
                                     target:self
                                   selector:@selector(loadAndInitializeMainMonitorView)
                                   userInfo:nil
                                    repeats:NO];
}

-(void) closeHowItWorksScreenAndLaunchTheSettingsScreen
{
    mSettingsViewController =
    [[SettingsViewController alloc] initWithNibName:@"SettingsViewController"
                                             bundle:nil];
    mSettingsViewController.mDelegate = self;

    self.window.rootViewController = mSettingsViewController;
    
    [window addSubview:mSettingsViewController.view];
    
}

-(StateMachineStates) getCurrentSMState
{
    return self.mMainCoordinator.mStateMachine.mCurrentState;
}

-(void) settingsViewControllerHasToClose
{
    [self loadAndInitializeMainMonitorView];
}

-(void) settingsViewControllerWantsToGoBack
{
    [self closeIntroScreenAndLaunchHowItWorksScreen];
}

-(void) tryConnectionAfterResolve:(NSNetService *)netService
{
    if (!netService)
    {
		return;
	}
    
    [PersistentStorage markFirstLaunchAsDone];
    
    //NSLog(@"\ncalling delegate for requestInitialHandshakeAfterResolve");
    [self.mMainCoordinator.mStateMachine requestInitialHandshakeAfterResolve:netService];
}

-(void) userWantsToChangeMode
{
    
}

-(void) closeIntroScreenAndLaunchHowItWorksScreen
{
    HowItWorksScreenViewController* howItWorksViewController =
    [[HowItWorksScreenViewController alloc] initWithNibName:@"HowItWorksScreenViewController"
                                                     bundle:nil];
    
    howItWorksViewController.mDelegate = self;
    self.window.rootViewController = howItWorksViewController;
}

@end