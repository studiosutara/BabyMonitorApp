//
//  MainMonitorViewController.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 6/27/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BMUtility.h"
#import "SoundAnimationView.h"
#import "SettingsViewController.h"
#import "SlideOutAttentionView.h"
#import "StateMachine.h"

typedef enum
{
    TALK_TO_BABY_BUTTON =0,
    START_MONITORING_BUTTON,
    MUTE_BUTTON,
    INFO_BUTTON,
    ATTENTION_BUTTON,
    SETTINGS_MENU_BUTTON,
}MainVCButtons;

@protocol MainMonitorVCDelegate <NSObject>
        
-(BMErrorCode) buttonPressed:(MainVCButtons) buttonPressed;
-(StateMachineStates) getCurrentState;

@end

@interface MainMonitorViewController : UIViewController
{
    __weak id <MainMonitorVCDelegate> mDelegate;
    
    uint mNumberOfMissedCallsOnBabyPhone;
    uint mBatteryLevelOnBabyPhone;
    uint mBabyPhoneIsSilenced;
    
    CGPoint mStartButtonCenter;
    IBOutlet SoundAnimationView* mSoundAnimationView;

    IBOutlet UILabel*     mModeNameLabel;
    IBOutlet UIButton*    mTalkToBabyButton;
    IBOutlet UILabel*     mTalkTobabyButtonSecondaryLabel;

    IBOutlet UIButton*    mStartMonitorButtonParentMode;
    IBOutlet UIButton*    mStartMonitorButtonBabyMode;

    IBOutlet UIButton*    mAttentionButton;
    IBOutlet UIButton*    mBatteryStatusButton;
    
    IBOutlet UIButton*    mPairingButton;
    IBOutlet UILabel*     mOvalButtonStatusLabel;
    IBOutlet UIImageView* mAnimatingIcon;
}

-(IBAction) startButtonParentModePressed:(id) sender;
-(IBAction) startButtonBabyModePressed:(id) sender;


-(IBAction) pairingStatusButtonPressed:(id) sender;
-(IBAction) talkToBabyButtonPressed:(id)sender;
-(IBAction) AttentionButtonPressed:(id)sender;
-(IBAction) BatteryButtonPressed:(id)sender;

-(void) changeMonitorMode; //:(MonitorMode) newMode;
-(void) changeMuteStatus:(bool) isMuted;
-(void) changeTalkToBabyStatus:(bool) isTalking;

-(void) updateBatteryLevelInfo:(NSNumber*) newLevel;
-(void) addToMissedCallInfo;
-(void) updateReachabilityLost;
-(void) updateReachabilityGained;
-(void) showConnectedWarning;

//@property IBOutlet AQLevelMeter* mLevelMeter;

@property IBOutlet UILabel*     mModeNameLabel;
@property IBOutlet UIButton*    mTalkToBabyButton;
@property IBOutlet UILabel*     mTalkTobabyButtonSecondaryLabel;


@property IBOutlet UIButton*    mStartMonitorButtonParentMode;
@property IBOutlet UIButton*    mStartMonitorButtonBabyMode;

@property IBOutlet UIButton*    mAttentionButton;
@property IBOutlet UIButton*    mBatteryStatusButton;
@property IBOutlet UIButton*    mPairingButton;
@property IBOutlet UILabel*     mOvalButtonStatusLabel;
@property IBOutlet SoundAnimationView* mSoundAnimationView;
@property IBOutlet SlideOutAttentionView* mSlideOutAnimationView;
@property IBOutlet UILabel*     mAdditionalInfoLabel;
@property IBOutlet UIImageView* mAnimatingIcon;

@property (weak) id <MainMonitorVCDelegate> mDelegate;
@end
