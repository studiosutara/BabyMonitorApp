//
//  BabyMonitorAppDelegate.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/20/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MainMonitorViewController.h"
#import <CoreTelephony/CTCall.h>
#import <CoreTelephony/CTCallCenter.h>
#import "MainViewControllerCoordinator.h"
#import "HowItWorksScreenViewController.h"
#import "LaunchViewController.h"

@interface BabyMonitorAppDelegate : NSObject <UIApplicationDelegate, IntroScreenDelegate, 
 StateMachineDelegate, HowItWorksScreenDelegate, SettingsViewControllerDelegate> 
{
    UIWindow*					window;
            
    CTCallCenter*               mCallCenter;
    
    NSString*                   mCurrentCallState;
    
    MainViewControllerCoordinator* mMainCoordinator;
    SettingsViewController*        mSettingsViewController;
    UINavigationController* mNavController;
    LaunchViewController* mLaunchController;
}
    
-(void) inComingConnectionRequestFrom:(NSString*) peerName;
-(void) connectionStatusChanged:(bool) isConnected withPeer:(NSString*)peerName isIncoming:(bool) incoming;

-(void) loadAndInitializeMainMonitorView;

-(void) closeHowItWorksScreenAndLaunchTheSettingsScreen;

-(void) tryConnectionAfterResolve:(NSNetService *)netService;
-(StateMachineStates) getCurrentSMState;

@property (nonatomic) IBOutlet UIWindow *window;    
@property (nonatomic, strong)NSString* mCurrentCallState;
@property (strong) MainViewControllerCoordinator* mMainCoordinator;
@end
