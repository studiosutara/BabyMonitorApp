//
//  SettingsViewController.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 7/16/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BMUtility.h"
#import "PMCViewController.h"
#import "StateMachine.h"

@protocol SettingsViewControllerDelegate <NSObject>
@optional
-(void) settingsViewControllerHasToClose;
-(void) settingsViewControllerWantsToGoBack;
-(void) tryConnectionAfterResolve:(NSNetService *)netService;
-(void) userWantsToChangeMode;
-(StateMachineStates) getCurrentSMState;
@end

typedef enum
{
    NOT_PAIRED,
    LOOKING_FOR_OTHER_DEVICES,
    DONE_LOOKING_FOR_DEVICES,
    CURRENTLY_PAIRING,
    CURRENTLY_PAIRED,
    PAIRING_FAILED,
    INVALID
}PairingStatus;

@interface SettingsViewController : UIViewController <PMCStatusDelegate>
{
    __weak id <SettingsViewControllerDelegate> mDelegate;
    PMCViewController*  mPMCViewController;
    MonitorMode         mOurMode;
    
    UIAlertView*        mChangePeerAlertView;
    
    UINavigationBar*    mNavBar; 
}

-(IBAction) swapModeButtonPressed;
-(IBAction) changePeerButtonPressed;
-(void) connectButtonPressed;
-(IBAction) tryAgainButtonPressed:(id)sender;
-(IBAction) cancelButtonPressed:(id)sender;

-(void) setupView;

-(void) setPairingStatus:(PairingStatus) newStatus andWithInfo:(id)info;
-(void) PMCIslookingForPeers:(bool)isStarting numOfPeersFound:(short)num withPeerName:(NSString*)peerName
;
-(void) PMCIsConnectingWithPeer:(NSString*)currentlyConnectingToPeer;
-(void) PMCConnectionWithPeerEndedWithError:(BMErrorCode) error peerName:(NSString*) str;
-(void) tryConnectionAfterResolve:(NSNetService *)netService;

@property IBOutlet UILabel* mPlaceNearBaby;
@property IBOutlet UILabel* mKeepWithYou;
@property IBOutlet UILabel* mBabyDeviceImage;
@property IBOutlet UIImageView* mParentDeviceImage;
@property IBOutlet UIButton* mCancelButton;

@property IBOutlet UILabel* mBabyDeviceLabel;
@property IBOutlet UILabel* mParentDeviceLabel;

@property IBOutlet UIButton* mSwapButton;

@property IBOutlet UIView*   mBottomStatusView;
@property IBOutlet UILabel*  mConnectionStatusLabel;
@property IBOutlet UIButton* mConnectButton;
@property IBOutlet UIButton* mTryAgainButton;
@property IBOutlet UIImageView* mPairingStatusIconImageView;

@property IBOutlet UIImageView* mBackground;

@property (weak) id <SettingsViewControllerDelegate> mDelegate;
@end
