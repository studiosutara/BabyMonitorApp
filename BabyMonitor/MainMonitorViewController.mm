//
//  MainMonitorViewController.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 6/27/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "MainMonitorViewController.h"
#import "BMUtility.h"
#import "Utilities.h"
#import "PersistentStorage.h"
#import "DDLog.h"
#import <MBProgressHUD.h>
#import <RNBlurModalView.h>

const int ddLogLevel = LOG_LEVEL_VERBOSE;

@interface MainMonitorViewController ()
@property (nonatomic) BOOL mConnectedWarningNotShown;
@property (nonatomic, strong) UILocalNotification *mBatteryNotification;
@property (nonatomic) uint m20PercentNotificationShown;
@property (nonatomic) uint m15PercentNotificationShown;
@property (nonatomic) uint m10PercentNotificationShown;
@property (nonatomic) uint m5PercentNotificationShown;
@end

@implementation MainMonitorViewController

@synthesize mAttentionButton;
@synthesize mBatteryStatusButton;
@synthesize mModeNameLabel;
@synthesize mPairingButton;
@synthesize mStartMonitorButtonParentMode;
@synthesize mStartMonitorButtonBabyMode;
@synthesize mTalkToBabyButton;
@synthesize mTalkTobabyButtonSecondaryLabel;
@synthesize mDelegate;
@synthesize mSoundAnimationView;
@synthesize mOvalButtonStatusLabel;
@synthesize mSlideOutAnimationView;
@synthesize mAdditionalInfoLabel;
@synthesize mAnimatingIcon;

-(void) dealloc
{
    DDLogInfo(@"\nMainViewController: deallocing MainViewController");
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:nil
                                                  object:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil 
               bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) 
    {
        NSLog(@"Signed up for kNotificationSMToUIStateChangeUpdate");
       [[NSNotificationCenter defaultCenter] addObserver:self
                                                selector:@selector(stateChangedForUI:)
                                                    name:kNotificationSMToUIStateChangeUpdate
                                                  object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(SMModeChanged:)
                                                     name:kNotificationSMToBMVCSMModeChanged
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(addToMissedCallInfo)
                                                     name:kNotificationPMToMainViewPeerPausedOnCallInterrupt
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateBatteryLevelInfo:)
                                                     name:kNotificationPMToMainViewPeerBatteryLevelUpdate
                                                   object:nil];
        
        mBatteryLevelOnBabyPhone = 0;
        mNumberOfMissedCallsOnBabyPhone = 0;
        self.m20PercentNotificationShown = NO;
        self.m15PercentNotificationShown = NO;
        self.m10PercentNotificationShown = NO;
        self.m5PercentNotificationShown = NO;
    }
    
    return self;
}

-(IBAction) startButtonBabyModePressed:(id) sender
{
    [self startButtonPressed];
}

-(IBAction) startButtonParentModePressed:(id) sender
{
    [self startButtonPressed];
}

-(void) startButtonPressed
{
    if(mDelegate && [mDelegate respondsToSelector:@selector(buttonPressed:)])
    {
        BMErrorCode error = [mDelegate buttonPressed:START_MONITORING_BUTTON];
        if(  error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nMainViewController: Error Start/Stop monitoring");
        }
    }
}

-(IBAction) pairingStatusButtonPressed:(id) sender
{
    if(mDelegate && [mDelegate respondsToSelector:@selector(buttonPressed:)])
    {
        BMErrorCode error = [mDelegate buttonPressed:SETTINGS_MENU_BUTTON];
        if(  error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nMainViewController: Error Launching settings menu monitoring");
        }
    }
}

-(IBAction) talkToBabyButtonPressed:(id)sender
{
    if(mDelegate && [mDelegate respondsToSelector:@selector(buttonPressed:)])
    {
        BMErrorCode error = [mDelegate buttonPressed:TALK_TO_BABY_BUTTON];
        if(  error != BM_ERROR_NONE)
        {
            DDLogInfo(@"\nMainViewController: Error Talk to Baby");
        }
    }
}

//-(IBAction) muteButtonPressed:(id)sender
//{
//    if(mDelegate && [mDelegate respondsToSelector:@selector(buttonPressed:)])
//    {
//        BMErrorCode error = [mDelegate buttonPressed:MUTE_BUTTON];
//        if(  error != BM_ERROR_NONE)
//        {
//            DDLogInfo(@"\nMainViewController: Error Muting");
//        }
//        else 
//        {
//            if([mMuteButtonLabel.text isEqualToString:@"Mute"])
//            {
//                mMuteButtonLabel.text = @"Unmute";
//            }
//            else 
//            {
//                mMuteButtonLabel.text = @"Mute";
//            }
//        }
//    }
//}

-(void) SMModeChanged: (NSNotification*) notice
{
//    NSNumber* num = (NSNumber*) [notice object];
//    int newMode = [num intValue];
//    
    [self changeMonitorMode]; //:(MonitorMode)newMode];
}

-(IBAction) infoButtonPressed:(id)sender
{
 	UINavigationController *aNavigationController =
    [[UINavigationController alloc] initWithNibName:@"InfoMenuViewController" bundle:nil];
	
	// Configure and show the window
	[self.view addSubview:[aNavigationController view]];
}

-(IBAction) BatteryButtonPressed:(id)sender
{
    //    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    //    hud.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MPCheckmark.png"]];
    //    hud.mode = MBProgressHUDModeCustomView;
    //    [hud hide:YES afterDelay:3];
    //    hud.labelText = @"Missed Calls";
    
    NSString* peerName = [PersistentStorage readPeerNameFromPersistentStorage];
    NSString* message = nil;
    
    if(mBatteryLevelOnBabyPhone)
    {
        if(peerName)
        {
            message =
            [NSString stringWithFormat:@"Battery on %@ is at %d%%", peerName, mBatteryLevelOnBabyPhone];
        }
        else
        {
            message =
            [NSString stringWithFormat:@"Battery level on the Baby Device is at %d%%", mBatteryLevelOnBabyPhone];
        }
    }
    else
    {
        if(peerName)
        {
            message = [NSString stringWithFormat:@"Battery Level update pending from %@", peerName];
        }
        else
        {
            message = @"Battery Level update pending";
        }
    }
    
    RNBlurModalView *modal = [[RNBlurModalView alloc] initWithViewController:self
                                                                       title:@"Battery Level"
                                                                     message:message];
    [modal show];
}

-(NSString*) getMissedCallsInfo
{
    NSString* peerName = [PersistentStorage readPeerNameFromPersistentStorage];
    NSString* message = nil;
    
    if(peerName)
    {
        message = [NSString stringWithFormat:@"%d Missed Call(s) on %@",
                   mNumberOfMissedCallsOnBabyPhone,
                   peerName];
    }
    else
    {
        message = [NSString stringWithFormat:@"%d Missed Call(s) on Baby Device",mNumberOfMissedCallsOnBabyPhone];
    }

    return message;
}

-(IBAction) AttentionButtonPressed:(id)sender
{
    NSString* message = [self getMissedCallsInfo];
    
    if(message)
    {
        RNBlurModalView *modal = [[RNBlurModalView alloc] initWithViewController:self
                                                                           title:@"Missed Calls"
                                                                         message:message];
        [modal show];
    }
    
    mNumberOfMissedCallsOnBabyPhone = 0;
    mAttentionButton.hidden = YES;
}

-(void) stateChangedForUI:(NSNotification*) notice
{
    NSNumber* num = (NSNumber*) [notice object];
    BabyMonitorStatesForUI state = (BabyMonitorStatesForUI)[num intValue];
    DDLogInfo(@"\nBMVC: stateChangedForUI = %d", state);

    switch (state)
    {
        case NOT_CONNECTED:
        {
            [self changeStateToNotConnected];
        }
            break;
            
        case CONNECTING:
        {
            [self changeStateToConnecting];
        }
            break;
            
        case CONNECTED_NOT_MONITORING:
        {
            NSLog(@"Conneted NOT MONITORING");
            [self changeStateToConnected];
        }
            break;
            
        case STARTING_MONITOR:
        {
            [self changeStateToStartingMonitor];
        }
            break;
          
        case MONITORING:
        {
            [self changeStateToMonitoring];
        }
            break;
         
        case LISTENING_OR_TALKING:
        {
            [self changeStateToTalkingOrListening];
        }
            break;
            
        case RESTARTING:
        {
            [self changeStateToRestarting];
        }
            break;
            
        default:
            break;
    }
}

-(void) changeStateToRestarting
{
    
}

-(void) changeStateToTalkingOrListening
{
    
    if(self.mTalkToBabyButton.enabled &&
       [self.mTalkToBabyButton.titleLabel.text isEqualToString:@"Talk to Baby"])
    {
        [self.mTalkToBabyButton setTitle:@"Resume" forState:UIControlStateNormal];
        
        self.mTalkTobabyButtonSecondaryLabel.hidden = NO;
        self.mTalkTobabyButtonSecondaryLabel.text = @"(Talk to Baby)";
        
        [mTalkToBabyButton setBackgroundImage:[UIImage imageNamed:@"StopMonRed.png"] forState:UIControlStateNormal];
    }
    
    if([mModeNameLabel.text isEqualToString:@"Baby Device"])
    {
        mOvalButtonStatusLabel.text = @"Listening to Parent";
    }
    else
    {
        mOvalButtonStatusLabel.text = @"Talking to Baby";
    }
    
    //NSLog(@"\nHere2");
    mStartMonitorButtonParentMode.userInteractionEnabled = NO;
    mStartMonitorButtonBabyMode.userInteractionEnabled = NO;
    
    [mStartMonitorButtonParentMode setBackgroundImage:[UIImage imageNamed:@"StartMonDisabled.png"]
                                   forState:UIControlStateNormal];
    
    [mStartMonitorButtonBabyMode setBackgroundImage:[UIImage imageNamed:@"StartMonDisabled.png"]
                                             forState:UIControlStateNormal];

    
    mPairingButton.hidden = YES;
}

-(void) changeStateToMonitoring
{
    @synchronized(self)
    {
        //NSLog(@"\nHere3");
        mStartMonitorButtonParentMode.userInteractionEnabled = YES;
        mStartMonitorButtonBabyMode.userInteractionEnabled = YES;
     //   mMuteButton.userInteractionEnabled = YES;
        
        //change the oval plate to "Monitoring"
        mOvalButtonStatusLabel.text = @"...Monitoring...";
        
        //change monitor button to "Stop"
        [self.mStartMonitorButtonParentMode setTitle:@"Stop" forState:UIControlStateNormal];
        [self.mStartMonitorButtonBabyMode setTitle:@"Stop" forState:UIControlStateNormal];
        
        [mStartMonitorButtonParentMode setBackgroundImage:[UIImage imageNamed:@"StopMonRed.png"] forState:UIControlStateNormal];
        [mStartMonitorButtonBabyMode setBackgroundImage:[UIImage imageNamed:@"StopMonRed.png"] forState:UIControlStateNormal];
        
        if([mModeNameLabel.text isEqualToString:@"Parent Device"])
        {
    
            if([self.mTalkToBabyButton.titleLabel.text isEqualToString:@"Stop"])
            {
                [self.mTalkToBabyButton setTitle:@"Talk to Baby" forState:UIControlStateNormal];
                self.mTalkTobabyButtonSecondaryLabel.hidden = YES;
                [self.mTalkToBabyButton setBackgroundImage:[UIImage imageNamed:@"TTB.png"] forState:UIControlStateNormal];
            }
            
            mTalkToBabyButton.enabled = YES;
            
            if(mNumberOfMissedCallsOnBabyPhone)
            {
                mAttentionButton.hidden = NO;
            }
            
        }
        
        self.mBatteryNotification = nil;
        mPairingButton.hidden = YES;
    }
}

-(void) changeStateToStartingMonitor
{
    @synchronized(self)
    {
        //NSLog(@"\nHere4");
        
        mStartMonitorButtonParentMode.userInteractionEnabled = NO;
        mStartMonitorButtonBabyMode.userInteractionEnabled = NO;

        //mMuteButton.userInteractionEnabled = NO;
        
                mPairingButton.hidden = YES;
        mOvalButtonStatusLabel.text = @"Working on it...";
    }
}

-(void) showConnectedWarning
{
    if(self.mConnectedWarningNotShown)
    {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MPCheckmark.png"]];
        hud.mode = MBProgressHUDModeCustomView;
        [hud hide:YES afterDelay:3];
        hud.labelText = @"Connected";
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);

        if([mModeNameLabel.text isEqualToString:@"Parent Device"])
        {
            hud.detailsLabelText = @"Don't forget to silence device near the Baby!";
        }
        else
        {
            hud.detailsLabelText = @"Don't forget to silence this device!";
        }
        
        self.mConnectedWarningNotShown = NO;
    }
}

-(void) changeStateToConnected
{
    @synchronized(self)
    {
        if([mModeNameLabel.text isEqualToString:@"Parent Device"])
        {
            //enable the "talk to baby button"
            if(![Utilities isAudioInputAvailable])
            {
                [mStartMonitorButtonParentMode setBackgroundImage:[UIImage imageNamed:@"StartMonDisabled.png"]
                                               forState:UIControlStateNormal];
                
                [mStartMonitorButtonBabyMode setBackgroundImage:[UIImage imageNamed:@"StartMonDisabled.png"]
                                                         forState:UIControlStateNormal];
                
                self.mTalkToBabyButton.enabled = YES;
                self.mTalkTobabyButtonSecondaryLabel.text = @"No mic";
            }
            else
            {
                self.mTalkToBabyButton.enabled = YES;
                mTalkToBabyButton.hidden = NO;
            }
            
            self.mTalkTobabyButtonSecondaryLabel.hidden = YES;
            [self.mTalkToBabyButton setTitle:@"Talk to Baby" forState:UIControlStateNormal];
            [mTalkToBabyButton setBackgroundImage:[UIImage imageNamed:@"TTB.png"] forState:UIControlStateNormal];
        
            //mNumberOfMissedCallsOnBabyPhone = 0;
            
           // DDLogInfo(@"\nMainMonitorController: Updated as Connected in Parent Mode");
        }
        else
        {
            if(![Utilities isAudioInputAvailable])
            {
                [mStartMonitorButtonParentMode setBackgroundImage:[UIImage imageNamed:@"StartMonDisabled.png"]
                                               forState:UIControlStateNormal];

                [mStartMonitorButtonBabyMode setBackgroundImage:[UIImage imageNamed:@"StartMonDisabled.png"]
                                                         forState:UIControlStateNormal];

                
                mOvalButtonStatusLabel.text = @"No mic available";
            }
            
            //DDLogInfo(@"\nMainMonitorController: Updated as Connected in Baby Mode");
        }
        
        //change the monitor button to "Start"
        [self.mStartMonitorButtonParentMode setTitle:@"Start" forState:UIControlStateNormal];
        [self.mStartMonitorButtonBabyMode setTitle:@"Start" forState:UIControlStateNormal];


        //change the pairing status icon to "connected"
     //   [mPairingButton setBackgroundImage:[UIImage imageNamed:@"SettingsIcon.png"]
     //                             forState:UIControlStateNormal];
        
        mPairingButton.hidden = NO;
        [mAnimatingIcon.layer removeAnimationForKey:@"NowPairing"];
        mAnimatingIcon.hidden = YES;
        //change the oval plate to "tap start to monitor"
        mOvalButtonStatusLabel.text = @"Tap Start to Monitor";
        
        //enable the start monitor button
        mStartMonitorButtonParentMode.userInteractionEnabled = YES;
        mStartMonitorButtonBabyMode.userInteractionEnabled = YES;

        //mMuteButton.userInteractionEnabled = YES;
        
        [mStartMonitorButtonParentMode setBackgroundImage:[UIImage imageNamed:@"StartMonGreen.png"]
                                       forState:UIControlStateNormal];

        [mStartMonitorButtonBabyMode setBackgroundImage:[UIImage imageNamed:@"StartMonGreen.png"]
                                                 forState:UIControlStateNormal];

        
        NSString* peerName = [PersistentStorage readPeerNameFromPersistentStorage];
        if(peerName)
        {
            mAdditionalInfoLabel.text = [NSString stringWithFormat:@"Connected to %@", peerName];
        }
    }
    
    [self showConnectedWarning];
}

-(void) changeStateToConnecting
{
    @synchronized(self)
    {
        if([mModeNameLabel.text isEqualToString:@"Parent Device"])
        {
            //disable the "talk to baby button"
            self.mTalkToBabyButton.enabled = NO;
        }
        
        //change the pairing status icon to "not connected"
//        [mPairingButton setBackgroundImage:[UIImage imageNamed:@"SettingsIcon.png"]
//                                  forState:UIControlStateNormal];
        mPairingButton.hidden = YES;
        //change the oval plate to "not connected"
        mOvalButtonStatusLabel.text = @"Searching for";
        
        NSString* peerName = [PersistentStorage readPeerNameFromPersistentStorage];
        if(peerName)
        {
            mAdditionalInfoLabel.text = [NSString stringWithFormat:@"%@", peerName];
        }

        UIImage* image = [UIImage imageNamed:@"PairingOngoing.png"];
        [mAnimatingIcon setImage:image];
        
        CABasicAnimation *fullRotation;
        fullRotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
        fullRotation.toValue = [NSNumber numberWithFloat:((360*M_PI)/180)];
        fullRotation.fromValue = [NSNumber numberWithFloat:0];
        fullRotation.duration = 5.0f;
        fullRotation.repeatCount = MAXFLOAT;
        
        mAnimatingIcon.hidden = NO;
        
        [mAnimatingIcon.layer addAnimation:fullRotation forKey:@"NowPairing"];

        //disable the start monitor button
        [mStartMonitorButtonParentMode setBackgroundImage:[UIImage imageNamed:@"StartMonDisabled.png"]
                                       forState:UIControlStateNormal];
        
        [mStartMonitorButtonBabyMode setBackgroundImage:[UIImage imageNamed:@"StartMonDisabled.png"]
                                                 forState:UIControlStateNormal];

        //NSLog(@"\nHere6");
        mStartMonitorButtonParentMode.userInteractionEnabled = false;
        mStartMonitorButtonBabyMode.userInteractionEnabled = false;
        //mMuteButton.userInteractionEnabled = false;
    }
}

-(void) changeStateToNotConnected
{
    @synchronized(self)
    {
        if([mModeNameLabel.text isEqualToString:@"Parent Device"])
        {
            //disable the "talk to baby button"
            self.mTalkToBabyButton.enabled = NO;

        }
        
        NSString* peerName = [PersistentStorage readPeerNameFromPersistentStorage];
        if(peerName)
        {
            mAdditionalInfoLabel.text = [NSString stringWithFormat:@"Start the app on %@.\n\nTap on settings button to connect to another device.", peerName];
        }

        if(!mNumberOfMissedCallsOnBabyPhone)
        {
            mAttentionButton.hidden = YES;
        }
        
        self.mBatteryStatusButton.hidden = YES;
        
        //change the pairing status icon to "not connected"
//        [mPairingButton setBackgroundImage:[UIImage imageNamed:@"SettingsIcon.png"]
//                                  forState:UIControlStateNormal];
        
        //change the oval plate to "not connected"
        mOvalButtonStatusLabel.text = @"Not Connected";

        [mAnimatingIcon.layer removeAnimationForKey:@"NowPairing"];
        mAnimatingIcon.hidden = YES;
        //disable the start monitor button
        [mStartMonitorButtonParentMode setBackgroundImage:[UIImage imageNamed:@"StartMonDisabled.png"]
                                       forState:UIControlStateNormal];
        [mStartMonitorButtonBabyMode setBackgroundImage:[UIImage imageNamed:@"StartMonDisabled.png"]
                                                 forState:UIControlStateNormal];


        mStartMonitorButtonParentMode.userInteractionEnabled = false;
        mStartMonitorButtonBabyMode.userInteractionEnabled = false;

        mPairingButton.hidden = NO;
    }
}

-(void) updateReachabilityLost
{
    self.mAdditionalInfoLabel.text = @"Wireless connection appears to be down";
}

-(void) updateReachabilityGained
{
    self.mAdditionalInfoLabel.text = @"Wireless connection is back up.";
}

-(void) updateBatteryLevelInfo:(NSNotification*) notice
{
    if(![mModeNameLabel.text isEqualToString:@"Parent Device"])
    {
        return;
    }
    
    NSNumber* num = (NSNumber*) [notice object];
   // DDLogInfo(@"\nBMVC: updateBatteryLevelInfo = %d", [num intValue]);
    mBatteryLevelOnBabyPhone = [num intValue];
        
    if(mBatteryLevelOnBabyPhone <= 20 )
    {
        self.mBatteryStatusButton.hidden = NO;
        UIApplicationState state = [[UIApplication sharedApplication] applicationState];
        if (state == UIApplicationStateBackground)
        {
            NSString* peerName = [PersistentStorage readPeerNameFromPersistentStorage];
            NSString* message = nil;

            if(mBatteryLevelOnBabyPhone)
            {
                if(peerName)
                {
                    message =
                    [NSString stringWithFormat:@"Battery on %@ is running low at %d percent.", peerName, mBatteryLevelOnBabyPhone];
                }
                else
                {
                    message =
                    [NSString stringWithFormat:@"Battery on the Baby Device is running low at %d percent.", mBatteryLevelOnBabyPhone];
                }
            }
            
            if( (mBatteryLevelOnBabyPhone == 20 && !self.m20PercentNotificationShown) ||
               (mBatteryLevelOnBabyPhone == 15 && !self.m15PercentNotificationShown) ||
               (mBatteryLevelOnBabyPhone == 10 && !self.m10PercentNotificationShown) ||
               (mBatteryLevelOnBabyPhone == 5 && !self.m5PercentNotificationShown) )
            {
                self.mBatteryNotification = [[UILocalNotification alloc] init];
                self.mBatteryNotification.fireDate = [NSDate date];
                self.mBatteryNotification.alertBody = message;
                [[UIApplication sharedApplication] scheduleLocalNotification:self.mBatteryNotification];
                
                if(mBatteryLevelOnBabyPhone == 20)
                    self.m20PercentNotificationShown = YES;
                
                if(mBatteryLevelOnBabyPhone == 15)
                    self.m15PercentNotificationShown = YES;

                if(mBatteryLevelOnBabyPhone == 10)
                    self.m10PercentNotificationShown = YES;

                if(mBatteryLevelOnBabyPhone == 5)
                    self.m5PercentNotificationShown = YES;

            }
        }

        [Utilities playBeepSound];
    }
    else
    {
        self.mBatteryStatusButton.hidden = YES;
    }
}

-(void) addToMissedCallInfo
{
    if(![mModeNameLabel.text isEqualToString:@"Parent Device"])
    {
        return;
    }
    
    DDLogInfo(@"\nBMVC: received missed call info from peer with num =%d ", mNumberOfMissedCallsOnBabyPhone);
    mNumberOfMissedCallsOnBabyPhone++;
    mAttentionButton.hidden = NO;
    UILocalNotification* notice = [[UILocalNotification alloc] init];
    notice.fireDate = [NSDate date];
    notice.alertBody = [self getMissedCallsInfo];
    [[UIApplication sharedApplication] scheduleLocalNotification:notice];

    //[self AttentionButtonPressed:nil];
}

//we not not going to worry about maintaing integrity or about
//validity of this operation
//we will assume that the main view controller is taking care of this.
-(void) changeMonitorMode
{
    MonitorMode newMode = [PersistentStorage readSMModeFromPersistentStorage];
    
    if(newMode == BABY_OR_TRANSMITTER_MODE)
    {
        mModeNameLabel.text = @"Baby Device";
        self.mTalkToBabyButton.enabled = NO;
        mTalkToBabyButton.hidden = YES;
        if(!mNumberOfMissedCallsOnBabyPhone)
            mAttentionButton.hidden = YES;
        
        //mStartMonitorButtonParentMode.center = CGPointMake(self.view.center.x, mStartMonitorButtonParentMode.center.y);
        mStartMonitorButtonParentMode.hidden = YES;
        mStartMonitorButtonBabyMode.hidden = NO;
    }
    else if(newMode == PARENT_OR_RECEIVER_MODE)
    {
        //mModeImageView.image = [UIImage imageNamed:@"ReceiverSmall.png"];
        mModeNameLabel.text = @"Parent Device";
        self.mTalkToBabyButton.enabled = YES;
        mTalkToBabyButton.hidden = NO;

        mStartMonitorButtonParentMode.hidden = NO;
        mStartMonitorButtonBabyMode.hidden = YES;
        
        [self.mSlideOutAnimationView setupView];
        //mStartMonitorButtonParentMode.center = mStartButtonCenter;

    }
}

-(void) changeTalkToBabyStatus:(bool) isTalking
{
    //if we are talking to baby
    //disable the start and mute buttons
    //change the oval status label to "Talking to baby"
    //change the TTB button label
    
    //if we stopped talking to baby
    //enable the start and mute buttons
    //change the oval status label to "Tap Start to Monitor"
    //Change the TTB button label
    
    if(isTalking)
    {
        
    }
    else
    {
        [self changeStateToConnected];
    }
    
}

-(void) changeMuteStatus:(bool) isMuted
{
    if(isMuted)
    {
        //change the mute button to unmute
        
    }
    else 
    {
        //change the unmute button to mute
    }
}

-(void) viewWillAppear:(BOOL)animated
{
    self.mBatteryNotification = nil;
    self.mConnectedWarningNotShown = YES;
}

-(void) viewDidDisappear:(BOOL)animated
{
}

- (void)viewDidLoad
{
    DDLogInfo(@"\nMainViewController: ViewDidLoad");
    
    [super viewDidLoad];
    
    self.mConnectedWarningNotShown = YES;
    
    mModeNameLabel.font = [UIFont fontWithName:@"Sansation" size:26];
    [self.mStartMonitorButtonParentMode.titleLabel setFont:[UIFont fontWithName:@"Sansation" size:22]];
    [self.mStartMonitorButtonBabyMode.titleLabel setFont:[UIFont fontWithName:@"Sansation" size:22]];

    [self.mTalkToBabyButton.titleLabel setFont:[UIFont fontWithName:@"Sansation" size:18]];
    mTalkTobabyButtonSecondaryLabel.font =
                        [UIFont fontWithName:@"Sansation" size:16];
    
    mOvalButtonStatusLabel.font = [UIFont fontWithName:@"Sansation" size:20];
    mAdditionalInfoLabel.font = [UIFont fontWithName:@"Sansation" size:16];
    [self.mSoundAnimationView initViews];
    
    mStartButtonCenter = mStartMonitorButtonParentMode.center;
    
    [self changeMonitorMode];
    self.mSlideOutAnimationView.frame = CGRectMake(mSlideOutAnimationView.frame.origin.x,
                                                   [Utilities getDeviceHeight],
                                                   mSlideOutAnimationView.frame.size.width,
                                                   mSlideOutAnimationView.frame.size.height);
    
    if([Utilities getDeviceHeight] == iPhone5ScreenSize)
    {
        CGRect tempRect;
        
        tempRect = self.mSoundAnimationView.frame;
        self.mSoundAnimationView.frame = CGRectMake(tempRect.origin.x,
                                                    tempRect.origin.y+20,
                                                    tempRect.size.width,
                                                    tempRect.size.height);
        
        tempRect = self.mOvalButtonStatusLabel.frame;
        self.mOvalButtonStatusLabel.frame = CGRectMake(tempRect.origin.x,
                                                       tempRect.origin.y+20,
                                                       tempRect.size.width,
                                                       tempRect.size.height);

        tempRect = self.mAdditionalInfoLabel.frame;
        self.mAdditionalInfoLabel.frame = CGRectMake(tempRect.origin.x,
                                                       tempRect.origin.y+20,
                                                       tempRect.size.width,
                                                       tempRect.size.height);

        tempRect = self.mStartMonitorButtonParentMode.frame;
        self.mStartMonitorButtonParentMode.frame = CGRectMake(tempRect.origin.x,
                                                     tempRect.origin.y+40,
                                                     tempRect.size.width,
                                                     tempRect.size.height);

        tempRect = self.mStartMonitorButtonBabyMode.frame;
        self.mStartMonitorButtonBabyMode.frame = CGRectMake(tempRect.origin.x,
                                                     tempRect.origin.y+40,
                                                     tempRect.size.width,
                                                     tempRect.size.height);

        tempRect = self.mTalkToBabyButton.frame;
        self.mTalkToBabyButton.frame = CGRectMake(tempRect.origin.x,
                                                     tempRect.origin.y+40,
                                                     tempRect.size.width,
                                                     tempRect.size.height);

        tempRect = self.mTalkTobabyButtonSecondaryLabel.frame;
        self.mTalkTobabyButtonSecondaryLabel.frame = CGRectMake(tempRect.origin.x,
                                                  tempRect.origin.y+40,
                                                  tempRect.size.width,
                                                  tempRect.size.height);

        tempRect = self.mPairingButton.frame;
        self.mPairingButton.frame = CGRectMake(tempRect.origin.x,
                                               [Utilities getDeviceHeight] - 52,
                                               tempRect.size.width, tempRect.size.height);
        
        
        tempRect = self.mAttentionButton.frame;
        self.mAttentionButton.frame = CGRectMake(tempRect.origin.x,
                                                 [Utilities getDeviceHeight] - tempRect.size.height-10,
                                                 tempRect.size.width, tempRect.size.height);
        
        tempRect = self.mBatteryStatusButton.frame;
        self.mBatteryStatusButton.frame = CGRectMake(tempRect.origin.x,
                                                 [Utilities getDeviceHeight] - tempRect.size.height-10,
                                                 tempRect.size.width, tempRect.size.height);

        
        tempRect = self.mAnimatingIcon.frame;
        CGFloat animationgIconY = tempRect.origin.y+20;
        self.mAnimatingIcon.frame = CGRectMake(tempRect.origin.x,
                                               animationgIconY,
                                     tempRect.size.width,
                                               tempRect.size.height);

//        tempRect = self.mSoundAnimationView.frame;
//        self.mSoundAnimationView.frame = CGRectMake(tempRect.origin.x, tempRect.origin.y,
//                                                    tempRect.size.width, tempRect.size.height);
    }
    else
    {
       // CGRect tempRect = self.mSoundAnimationView.frame;
//        self.mSoundAnimationView.frame = CGRectMake(tempRect.origin.x, tempRect.origin.y,
//                                                    tempRect.size.width, tempRect.size.height-30);
    }
    
   StateMachineStates state = [self.mDelegate getCurrentState];
    NSLog(@"View did load state = %d", state);
   if([StateMachine isAConnectedState:state])
   {
       [self changeStateToConnected];
   }
   else
   {
       [self changeStateToNotConnected];
   }
   
    self.mBatteryStatusButton.hidden = YES;

    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
