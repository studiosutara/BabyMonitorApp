//
//  MainViewControllerCoordinator.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 6/21/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StateMachine.h"
#import "MainMonitorViewController.h"
#import "Reachability.h"

@interface MainViewControllerCoordinator : NSObject <MainMonitorVCDelegate, StateMachineDelegate, SettingsViewControllerDelegate>
{
    StateMachine*                   mStateMachine;
    
    //Reachability*                   mReachability;
    
    MainMonitorViewController*      mMainMonitorViewController;
    
    Reachability*                   mWifiReachability;
    Reachability*                   mPeerReachability;
    
    SettingsViewController* mSettingsViewController;
    NSTimer*                        mBatteryLevelUpdateTimer;
}

- (id)initAndLaunchView:(bool) launchView;
-(void) startMainVCCoordinator;

-(void) printAppState;

-(void) handleAppWillGoToBackground:(bool)isCallActive;
-(BMErrorCode) handleAppWillComeToForeground;

//Peer wants to disconnect with us
-(void) disconnectedWithPeer;

//TEST CODE ONLY
-(void) userWantsTodisconnectWithPeer;

-(BMErrorCode) startStopMonitoring;
-(void) userWantsToSwitchDevice;
-(BMErrorCode) userWantsToTalkToBaby;

-(BMErrorCode) buttonPressed:(MainVCButtons) buttonPressed;

-(void) inComingConnectionRequestFrom:(NSString*) peerName;
-(void) monitoringStatusChanged:(bool) isStarted;
-(void) talkingToBaby:(bool) isTalking;
-(void) connectionStatusChanged:(bool) isConnected withPeer:(NSString*)peerName isIncoming:(bool) incoming;

-(void) settingsViewControllerHasToClose;
-(void) tryConnectionAfterResolve:(NSNetService *)netService;
-(void) userWantsToChangeMode;

-(StateMachineStates) getCurrentState;
-(StateMachineStates) getCurrentSMState;

-(void) interruptionBegan;
-(void) interruptionEnded;

@property (nonatomic) StateMachine*              mStateMachine;
@property MainMonitorViewController*      mMainMonitorViewController;
@end
