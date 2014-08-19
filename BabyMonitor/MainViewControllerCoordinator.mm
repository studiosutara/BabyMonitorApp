//
//  MainViewControllerCoordinator.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 6/21/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "MainViewControllerCoordinator.h"
#import "DDLog.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define BATTERY_LEVEL_UPDATE_TIMER 60

const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation MainViewControllerCoordinator

@synthesize mStateMachine;
@synthesize mMainMonitorViewController;

-(void) dealloc
{
    //DDLogInfo(@"\nBMVC: deallocing MainControllerCoordinator");
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:nil
                                                  object:nil];
}

- (id)initAndLaunchView:(bool) launchView
{
    if ( (self = [super init]) ) 
	{
       // DDLogInfo(@"\nBMVC: MainControllerCoordinator init");
    }
    
    return  self;
}

-(void) interruptionBegan
{
   // DDLogInfo(@"\nBMVC: interruptionBegan");
    
    if(self.mStateMachine.mCurrentState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA ||
       self.mStateMachine.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA ||
       self.mStateMachine.mCurrentState == STATE_BABYMODE_LISTENING_TO_PARENT ||
       self.mStateMachine.mCurrentState == STATE_PARENTMODE_TALKING_TO_BABY)
    {
        [Utilities deactivateAudioSession];
    }
}

-(void) interruptionEnded
{
    DDLogInfo(@"\nBMVC: interruptionEnded");
    [self setupAudioSession];
    [Utilities activateAudioSession];
}

void AQInterruptionListenerCallback
(
 void *                  inClientData,
 UInt32                  inInterruptionState
 )
{
    //NSLog(@"\nAQPlayer: AQInterruptionListenerCallback called");
    
    MainViewControllerCoordinator* mainVCC = (__bridge MainViewControllerCoordinator*) inClientData;
    if(!mainVCC)
    {
      //  NSLog(@"\nBMVC: Invalid MainViewControllerCoordinator");
        return;
    }
    
    if(inInterruptionState == kAudioSessionBeginInterruption)
    {
       // NSLog(@"\nAQPlayer: INTERRUPTION BEGAN");
        
        [mainVCC interruptionBegan];
        
    }
    else if(inInterruptionState == kAudioSessionEndInterruption)
    {
       // NSLog(@"\nAQPlayer: INTERRUPTION ENDED");
        [mainVCC interruptionEnded];
    }
    
    return;
}

-(BMErrorCode) setupAudioSession
{    
    OSStatus error = 0;

    DDLogInfo(@"\nBMVC: setupAudioSession");
    // Set the audio session category so that we continue to play if the
    // iPhone/iPod auto-locks.
    //TODO: set cllback here
    error = AudioSessionInitialize (
                                    NULL,                          // 'NULL' to use the default (main) run loop
                                    NULL,                          // 'NULL' to use the default run loop mode
                                    AQInterruptionListenerCallback, // a reference to your interruption callback
                                    (__bridge void*)self           // data to pass to your interruption listener callback
                                    );
    if(error)
    {
        DDLogInfo(@"\nBMVC: AudioSessionInitialize error: ");
        [Utilities print4char_errorcode:error];
        
        //return BM_ERROR_FAIL;
    }
////------------------------------------------------------------------------------------------------------------------------
    
    UInt32 sessionCategory = 0;
    
    //If we are in the parent mode then 
    
    if( [Utilities isAudioInputAvailable] )
    {
        sessionCategory = kAudioSessionCategory_PlayAndRecord;
    }
    else
    {
        if(self.mStateMachine.mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE)
        {
            DDLogInfo(@"\nBMVC: Error: in BM, but no Audio input available");
        }
        else 
        {
            sessionCategory = kAudioSessionCategory_MediaPlayback;
        }
    }
    
    if(sessionCategory)
    {
        error = AudioSessionSetProperty (
                                         kAudioSessionProperty_AudioCategory,
                                         sizeof (sessionCategory),
                                         &sessionCategory
                                         );
        if(error)
        {
            DDLogInfo(@"\nBMVC: Error AudioSessionSetProperty kAudioSessionProperty_AudioCategory: ");
            [Utilities print4char_errorcode:error];
        }
    }
////------------------------------------------------------------------------------------------------------------------------
    
    UInt32 category = TRUE;
    error = AudioSessionSetProperty (
                                     kAudioSessionProperty_OverrideCategoryMixWithOthers,
                                     sizeof (UInt32),
                                     &category
                                     );			
    if(error)
    {
        DDLogInfo(@"\nBMVC: Error AudioSessionSetProperty kAudioSessionProperty_OverrideCategoryMixWithOthers");
        [Utilities print4char_errorcode:error];
    }
////------------------------------------------------------------------------------------------------------------------------
    
    UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;  // 1
    error = AudioSessionSetProperty (
                                     kAudioSessionProperty_OverrideAudioRoute,                         // 2
                                     sizeof (audioRouteOverride),                                      // 3
                                     &audioRouteOverride                                               // 4
                                     );
    if(error)
    {
        DDLogInfo(@"\nBMVC: AudioSessionSetProperty kAudioSessionProperty_OverrideAudioRoute error");
    }
////------------------------------------------------------------------------------------------------------------------------
   
    //[Utilities playBeepSound];

    /*error = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, NULL, NULL);
    if (error) printf("ERROR ADDING AUDIO SESSION PROP LISTENER! %ld\n", error);

    // we also need to listen to see if input availability changes
    error = AudioSessionAddPropertyListener(kAudioSessionProperty_AudioInputAvailable, NULL, NULL);
    if (error) printf("ERROR ADDING AUDIO SESSION PROP LISTENER! %ld\n", error);*/
    
    return BM_ERROR_NONE;
}

-(void) willResignActive
{
    DDLogInfo(@"\nBMVC: UIApplicationWillResignActiveNotification POsted");
}

-(void) startMainVCCoordinator
{
       //initialize the state machine
    mStateMachine = [[StateMachine alloc] init];
    
    //SM starts all the other associated modules
    [mStateMachine start];
    mStateMachine.mDelegate = self;    
    
    [self setupAudioSession];
    
    [[NSNotificationCenter defaultCenter] addObserver: self 
                                             selector: @selector(reachabilityChanged:) 
                                                 name: kReachabilityChangedNotification 
                                               object: nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(SMModeChanged:)
                                                 name:kNotificationSMToBMVCSMModeChanged
                                               object:nil];
    
    mWifiReachability = [Reachability reachabilityForLocalWiFi];
	[mWifiReachability startNotifier];
}

-(void) SMModeChanged: (NSNotification*) notice
{
   // DDLogInfo(@"\nBMVC: SMModeChanged");
    [self setupBatteryTimer];
}

- (void) reachabilityChanged: (NSNotification*)note
{
    DDLogInfo(@"\nBMVC: Reachability changed! Current state is %@",
          [self.mStateMachine.mReadableStateTable objectAtIndex:self.mStateMachine.mCurrentState]);
    
	Reachability* curReach = [note object];
	NSParameterAssert([curReach isKindOfClass: [Reachability class]]);
    
    [self.mStateMachine reachabilityChanged:[curReach currentReachabilityStatus]];
    
    if([curReach currentReachabilityStatus] == NotReachable)
    {
        [self.mMainMonitorViewController updateReachabilityLost];
    }
    else if([curReach currentReachabilityStatus] == ReachableViaWiFi)
    {
        //  DDLogInfo(@"\nStateMachine: Now reachable via Wifi");
        [self.mMainMonitorViewController updateReachabilityGained];
    }
}

-(StateMachineStates) getCurrentState
{
    NSLog(@"MainController: getCurrentState %d", self.mStateMachine.mCurrentState);
    return self.mStateMachine.mCurrentState;
}

-(StateMachineStates) getCurrentSMState
{
    NSLog(@"MainController: getCurrentState %d", self.mStateMachine.mCurrentState);
    return self.mStateMachine.mCurrentState;
}

-(BMErrorCode) buttonPressed:(MainVCButtons) buttonPressed
{
    BMErrorCode error = BM_ERROR_NONE;
    
    switch (buttonPressed) 
    {
        case START_MONITORING_BUTTON:
            return [self startStopMonitoring];
            break;
            
        case TALK_TO_BABY_BUTTON:
        {
            return [self userWantsToTalkToBaby];
        }
            break;
            
        case MUTE_BUTTON:
        {
            return [self userWantsToMuteVolume];
        }
            break;
            
        case SETTINGS_MENU_BUTTON:
        {
            mSettingsViewController = nil;
            
            mSettingsViewController =
            [[SettingsViewController alloc] init];
            
            mSettingsViewController.mDelegate = self;
            
            [self.mMainMonitorViewController presentViewController:mSettingsViewController animated:YES completion:nil];
             //addSubview:mSettingsViewController.view];

        }
        default:
            break;
    }
    
    return error;
}

-(void) printAppState
{
    [mStateMachine printAppState];
}

-(BMErrorCode) handleAppWillComeToForeground
{
   // DDLogInfo(@"\nBMVC: handleAppWillComeToForeground");
    
    if(self.mStateMachine.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA ||
       self.mStateMachine.mCurrentState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA||
       self.mStateMachine.mCurrentState == STATE_PARENTMODE_TALKING_TO_BABY ||
       self.mStateMachine.mCurrentState == STATE_BABYMODE_LISTENING_TO_PARENT)
    {
        [self SMStartAnimation];
    }
    
    return [mStateMachine handleAppWillComeToForeground];
}

-(void) handleAppWillGoToBackground:(bool) isCallActive
{
   // DDLogInfo(@"\nBMVC: handleAppWillGoToBackground" );
    if(self.mStateMachine.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA ||
       self.mStateMachine.mCurrentState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA)
    {
        //this should save some precious battery
        [self SMStopAnimation];
    }
    else
    {
        [self stopBatteryLevelUpdateTimer];
    }
    
    [self.mStateMachine handleAppWillGoToBackground:isCallActive];
}

//TEST CODE ONLY
//There is no feature that requires for this function alone to be called currently.
//As per the current feature set, this function is to be used only for switch device
//Switch Device ===> Disconnect with current device, followed by discover adn connect
//with another device
-(void) userWantsTodisconnectWithPeer
{
    if(mStateMachine.mCurrentState == STATE_CONNECTED_TO_PEER)
    {
        if([self.mStateMachine userWantsToDisconnectWithPeer] == BM_ERROR_NONE)
        {
            return;
        }
    }
    
    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:Nil 
                                                        message:@"Not in a state to disconnect right now" 
                                                       delegate:self 
                                              cancelButtonTitle:@"OK" 
                                              otherButtonTitles:nil];    
    [alertView show];
    
}

//Peer wants to disconnect with us
-(void) disconnectedWithPeer
{
   // DDLogInfo(@"\nBMVC: Disconnected with Peer. Now presenting peer picker");
    //[self.mBabyMonitorView disconnectDone];
    //[self presentPeerPicker:nil];
}

-(BMErrorCode) startStopMonitoring
{
    BMErrorCode error = BM_ERROR_NONE;
    
   // DDLogInfo(@"\nBMVC: Start/StopMonitoring called");
    //If playing we have to stop
    if([mStateMachine isCurrentlyRecording] || [mStateMachine isCurrentlyPlaying])
    {
        error = [mStateMachine userWantsToStopMonitoring:YES];
        if( error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nBMVC: Error stopping monitoring");
        }
    }
    
    //We need to start
    else if([mStateMachine isReadyToStartRecordingAndSending] || 
            [mStateMachine isReadyToStartReceivingAndPlaying])
    {
        error = [mStateMachine userWantsToStartMonitoring];
        if(error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nBMVC: Error starting monitoring");
        }
    }
    else if([mStateMachine isTalkingToBaby] ||
            [mStateMachine isListeningToParent])
    {
        error = [mStateMachine userWantsToTalkToBaby];
        if(error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nBMVC: Error Stopping talking to Baby");
        }
    }
    else 
    {
        DDLogInfo(@"\nBMVC: not starting: SM state is %@", 
              [self.mStateMachine.mReadableStateTable objectAtIndex:self.mStateMachine.mCurrentState]);
    }
    
    if(error != BM_ERROR_NONE)
        DDLogInfo(@"\nBMVC: startStopMonitoring returned error %d", error );
    
   // DDLogInfo(@"\nBMVC: startStopMonitoring returns");
    
    return error;
}

-(void) userWantsToChangeMode
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if( (error = [mStateMachine userToggledMode] ) != BM_ERROR_NONE)
    {
        DDLogInfo(@"\nBMVC: error toggling mode");
    }
    else 
    {
       // DDLogInfo(@"\nBMVC: Mode toggled");
    }
    
    return;
}

-(void) userWantsToSwitchDevice
{ 
  //  DDLogInfo(@"\nBMVC: user wants to switch device, disconnecting with the current peer first");
    
    if(mStateMachine.mCurrentState == STATE_CONNECTED_TO_PEER)
    {
        //Once we are successfully disconnected with peer, we go ahead and show the peer picker.
        if([self.mStateMachine userWantsToDisconnectWithPeer] == BM_ERROR_NONE)
        {
            DDLogInfo(@"\nBMVC: Error disconnecting with the peer");
        }
    }
    
}

-(BMErrorCode) userWantsToTalkToBaby
{
    BMErrorCode error = BM_ERROR_NONE;
    
   // DDLogInfo(@"\nBMVC: User wants to talk to baby in state %@",
     //         [mStateMachine.mReadableStateTable objectAtIndex:mStateMachine.mCurrentState]);
    
    error = [self.mStateMachine userWantsToTalkToBaby];
    
    return error;
}

-(BMErrorCode) userWantsToMuteVolume
{
    return [self.mStateMachine userWantsToMuteVolume];
}

-(void) inComingConnectionRequestFrom:(NSString*) peerName
{
             
}
         
-(void) connectionStatusChanged:(bool)isConnected withPeer:(NSString*)peerName isIncoming:(bool) incoming
{
    //DDLogInfo(@"\nBMVC: connectionStatusChanged");
    [self setupBatteryTimer];
    
    if(mSettingsViewController)
    {
        [mSettingsViewController setupView];
    }
}

-(void) setupBatteryTimer
{
    //DDLogInfo(@"\nBMVC: setupBatteryTimer called");
    
    bool isConnected = [StateMachine isAConnectedState:self.mStateMachine.mCurrentState];
    
    if(isConnected && self.mStateMachine.mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE)
    {
        [self startBatteryLevelUpdateTimer];
    }
    else
    {
        [self stopBatteryLevelUpdateTimer];
    }
}

-(void) startBatteryLevelUpdateTimer
{
    if(mBatteryLevelUpdateTimer)
        [self stopBatteryLevelUpdateTimer];
    
    mBatteryLevelUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:BATTERY_LEVEL_UPDATE_TIMER
                                                                      target:self
                                                                    selector:@selector(batteryLevelUpdateTimerFired:)
                                                                    userInfo:nil
                                                                     repeats:YES];
    
    //DDLogInfo(@"\nMediaPlayer: Started: startBatteryLevelUpdateTimer");
}
                            
-(void) stopBatteryLevelUpdateTimer
{
    if(mBatteryLevelUpdateTimer)
        [mBatteryLevelUpdateTimer invalidate];
    
    mBatteryLevelUpdateTimer = nil;
        
    //DDLogInfo(@"\nBMVC: Stopped: stopBatteryLevelUpdateTimer");
}
                                    
-(void) batteryLevelUpdateTimerFired:(NSTimer*) timer
{
    //DDLogInfo(@"\nBMVC: batteryLevelUpdateTimerFired");
    [mStateMachine.mProtocolManager getBatteryLevelPacketAndSend];
}
                                    
-(BMErrorCode) SMStartAnimation
{
    //self.mMainMonitorViewController.mSoundAnimationView.hidden = NO;
 
    if(mStateMachine.mCurrentState == STATE_BABYMODE_LISTENING_TO_PARENT ||
       mStateMachine.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA)
    {
        if(mStateMachine.mMediaPlayer && mStateMachine.mMediaPlayer.mAQPlayer)
            [self.mMainMonitorViewController.mSoundAnimationView
             setMAudioQueue:mStateMachine.mMediaPlayer.mAQPlayer.mAudioQueue];
    }
    else if(mStateMachine.mCurrentState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA ||
            mStateMachine.mCurrentState == STATE_PARENTMODE_TALKING_TO_BABY)
    {
        if(mStateMachine.mMediaRecorder && mStateMachine.mMediaRecorder.mAQRecorder)
            [self.mMainMonitorViewController.mSoundAnimationView
             setMAudioQueue:mStateMachine.mMediaRecorder.mAQRecorder.mQueue];
    }
    
    return BM_ERROR_NONE;
}

-(BMErrorCode) SMStopAnimation
{
    [self.mMainMonitorViewController.mSoundAnimationView stopAnimation];
    //mMainMonitorViewController.mSoundAnimationView.hidden = YES;
    
    return BM_ERROR_NONE;
}

-(void) monitoringStatusChanged:(bool) isStarted
{
    if(isStarted)
    {
        struct sockaddr* localAddress = (struct sockaddr*) malloc(sizeof(struct sockaddr));
        struct sockaddr* remoteAddress= (struct sockaddr*) malloc(sizeof(struct sockaddr));
        
        if(mStateMachine.mCurrentBabyMonitorMode == PARENT_OR_RECEIVER_MODE)
        {
            [self.mStateMachine.mMediaPlayer getLocalAddress:&localAddress andRemoteAddress:&remoteAddress];
        }
        else if(mStateMachine.mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE)
        {
            [self.mStateMachine.mMediaRecorder getLocalAddress:&localAddress andRemoteAddress:&remoteAddress];
        }
        
       //start the address based reachability interface
       //mPeerReachability = [Reachability reachabilityForHost:&localAddress andRemoteAddress:&remoteAddress];
       [mPeerReachability startNotifier];
    }
    else 
    {
    }
}

-(void) talkingToBaby:(bool) isTalking
{
    [self.mMainMonitorViewController changeTalkToBabyStatus:isTalking];
}


-(void) settingsViewControllerHasToClose
{
    [self.mMainMonitorViewController dismissViewControllerAnimated:YES completion:nil];
    mSettingsViewController = nil;
}

-(void) tryConnectionAfterResolve:(NSNetService *)netService
{
    if (!netService)
    {
		return;
	}
        
    DDLogInfo(@"\nBMVC: calling delegate for requestInitialHandshakeAfterResolve");
    [self.mStateMachine requestInitialHandshakeAfterResolve:netService];
}

////////////////////////////////Reachability Functions////////////////////////////////////


@end
