//
//  SettingsViewController.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 7/16/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "SettingsViewController.h"
#import "StateMachine.h"
#import "PersistentStorage.h"
#import "DDLog.h"
const int ddLogLevel = LOG_LEVEL_VERBOSE;

@interface SettingsViewController ()

@end

@implementation SettingsViewController

@synthesize mDelegate;
@synthesize mBabyDeviceLabel;
@synthesize mParentDeviceLabel;
@synthesize mKeepWithYou;
@synthesize mPlaceNearBaby;
@synthesize mBabyDeviceImage;
@synthesize mParentDeviceImage;

@synthesize mSwapButton;

@synthesize mConnectionStatusLabel;
@synthesize mConnectButton;
@synthesize mBottomStatusView;
@synthesize mPairingStatusIconImageView;
@synthesize mTryAgainButton;

@synthesize mCancelButton;

-(void) dealloc
{
    DDLogInfo(@"\nSettingsViewController: dealloc");
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:nil
                                                  object:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) 
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(SMModeChanged:)
                                                     name:kNotificationSMToBMVCSMModeChanged
                                                   object:nil];

        // Custom initialization
    }
    return self;
}

-(void) setupView
{
    DDLogInfo(@"\nSettingsVC: setupView");
    
    self.mParentDeviceLabel.font = [UIFont fontWithName:@"Sansation" size:18];
    self.mBabyDeviceLabel.font = [UIFont fontWithName:@"Sansation" size:18];

    StateMachineStates state = [self.mDelegate getCurrentSMState];
    bool isConnected = [StateMachine isAConnectedState:state];

    mOurMode = [PersistentStorage readSMModeFromPersistentStorage];
    if(mOurMode != INVALID_MODE)
    {
        NSString* name = [[UIDevice currentDevice] name];
        if(mOurMode == PARENT_OR_RECEIVER_MODE)
        {
            self.mParentDeviceLabel.text = name;
        }
        else 
        {
            self.mBabyDeviceLabel.text = name;
        }
    }
    
    NSString* peer = nil;
    peer = [PersistentStorage readPeerNameFromPersistentStorage];
    
    mKeepWithYou.font = [UIFont fontWithName:@"Sansation" size:15];
    mPlaceNearBaby.font = [UIFont fontWithName:@"Sansation" size:15];
    mConnectionStatusLabel.font = [UIFont fontWithName:@"Sansation" size:16];
    
    if(peer && isConnected)
    {
        mConnectionStatusLabel.text = @"Connected. Ready to start monitoring.";
        mConnectionStatusLabel.hidden = NO;
        
        mParentDeviceLabel.textColor = [UIColor blackColor];
        mBabyDeviceLabel.textColor = [UIColor blackColor];

        [mPairingStatusIconImageView.layer removeAnimationForKey:@"NowPairing"];
        mPairingStatusIconImageView.hidden = YES;
        
        mBabyDeviceImage.alpha = 1;

        [self addHideSelfTarget];
        
        if(mOurMode == PARENT_OR_RECEIVER_MODE)
        {
            mBabyDeviceLabel.text = peer;
        }
        else
        {
            mParentDeviceLabel.text = peer;
        }
        
        mSwapButton.enabled = YES;
    }
    else if(peer && !isConnected)
    {
        mParentDeviceLabel.textColor = [UIColor blackColor];
        mBabyDeviceLabel.textColor = [UIColor blackColor];

        mConnectionStatusLabel.text = [NSString stringWithFormat:@"%@ does not appear to be online.\n\nTry looking for another device?", peer];
        
        //[self addHideSelfTarget];
        mConnectButton.hidden = YES;
        [mPairingStatusIconImageView.layer removeAnimationForKey:@"NowPairing"];
        mPairingStatusIconImageView.hidden = YES;
        mCancelButton.hidden = NO;
        mTryAgainButton.hidden = NO;

        if(mOurMode == PARENT_OR_RECEIVER_MODE)
        {
            mBabyDeviceLabel.text = peer;
            mBabyDeviceImage.alpha = .6;
        }
        else
        {
            mParentDeviceLabel.text = peer;
            mParentDeviceImage.alpha = .6;
        }
    }
    else if(!peer && !isConnected)
    {
        if(mOurMode == PARENT_OR_RECEIVER_MODE)
        {
            mBabyDeviceLabel.textColor = [UIColor redColor];

            mBabyDeviceLabel.text = @"No Device(s) Found";
            mBabyDeviceImage.alpha = .6;
        }
        else
        {
            mParentDeviceLabel.textColor = [UIColor redColor];

            mParentDeviceLabel.text = @"No Device(s) Found";
            mParentDeviceImage.alpha = .6;
        }
        
        [self startLookupProcess];
    }
    
    if([Utilities getDeviceHeight] == iPhone5ScreenSize)
    {
        self.mBackground.frame = CGRectMake(0, 0, self.mBackground.frame.size.width, iPhone5ScreenSize);
    }
    
}

-(void) addHideSelfTarget
{
    mConnectButton.hidden = NO;
    mTryAgainButton.hidden = YES;
    mCancelButton.hidden = YES;
    
    [mConnectButton setTitle:@"Done" forState:UIControlStateNormal];

    [mConnectButton removeTarget:self
                          action:nil
                forControlEvents:UIControlEventTouchDown];
    
    [mConnectButton addTarget:self
                       action:@selector(hideSelf)
             forControlEvents:UIControlEventTouchDown];
}

-(void) addTryAgainTarget
{
    mConnectButton.hidden = NO;
    mTryAgainButton.hidden = YES;
    mCancelButton.hidden = YES;
    
    [mConnectButton setTitle:@"Try Again" forState:UIControlStateNormal];

    [mConnectButton removeTarget:self
                          action:nil
                forControlEvents:UIControlEventTouchDown];
    
    [mConnectButton addTarget:self
                       action:@selector(tryAgainButtonPressed:)
             forControlEvents:UIControlEventTouchDown];
    
}

-(void) addConnectButtonPressed
{
    self.mConnectButton.hidden = YES;
    self.mTryAgainButton.hidden = NO;
    self.mCancelButton.hidden = NO;
    
    [mTryAgainButton setTitle:@"Sure" forState:UIControlStateNormal];

    [mTryAgainButton removeTarget:self
                          action:nil
                forControlEvents:UIControlEventTouchDown];

    [mTryAgainButton addTarget:self
                       action:@selector(connectButtonPressed)
             forControlEvents:UIControlEventTouchDown];

}

-(void) SMModeChanged: (NSNotification*) notice
{
    if(mOurMode == PARENT_OR_RECEIVER_MODE)
        mOurMode = BABY_OR_TRANSMITTER_MODE;
    else
        mOurMode = PARENT_OR_RECEIVER_MODE;
    
    //[self switchDeviceNames];
    [NSTimer scheduledTimerWithTimeInterval:.3
                                     target:self
                                   selector:@selector(setupView)
                                   userInfo:nil
                                    repeats:NO];    
}

-(void) switchDeviceNames
{
    CGPoint babyLabelCenter = mBabyDeviceLabel.center;
    CGPoint parentLabelCenter = mParentDeviceLabel.center;
    
    // Setting the animation (animates the mask layer)
    CABasicAnimation *babyLabelAnimation = [CABasicAnimation animationWithKeyPath:@"babyLabel"];
    babyLabelAnimation.toValue = [NSNumber numberWithFloat:parentLabelCenter.x];
    babyLabelAnimation.fromValue = [NSNumber numberWithFloat:babyLabelCenter.x];
    babyLabelAnimation.repeatCount = 1;
    babyLabelAnimation.duration = 1.0f;
    [mBabyDeviceImage.layer addAnimation:babyLabelAnimation forKey:@"babyLabel"];
    
    CABasicAnimation *parentLabelAnimation = [CABasicAnimation animationWithKeyPath:@"parentLabel"];
    parentLabelAnimation.toValue = [NSNumber numberWithFloat:babyLabelCenter.x];
    parentLabelAnimation.fromValue = [NSNumber numberWithFloat:parentLabelCenter.x];
    parentLabelAnimation.repeatCount = 1;
    parentLabelAnimation.duration = 1.0f;
    [mParentDeviceLabel.layer addAnimation:parentLabelAnimation forKey:@"parentLabel"];
    
//    CGRect babyFrame = mBabyDeviceLabel.frame;
//    mBabyDeviceLabel.frame = mParentDeviceLabel.frame;
//    mParentDeviceLabel.frame = babyFrame;

}

-(void) startLookupProcess
{
    if(mPMCViewController)
    {
        [mPMCViewController stopSearchingForServices];
        mPMCViewController = nil;
    }
    
    mPMCViewController = [[PMCViewController alloc] init];
    mPMCViewController.mStatusDelegate = self;
    [mPMCViewController searchForServicesOfType:[Utilities getBonjourType]
                                            inDomain:@"local"];
}

-(void) PMCIslookingForPeers:(bool)isStarting 
             numOfPeersFound:(short)num 
                withPeerName:(NSString*)peerName
{
    NSLog(@"PMCIslookingForPeers isstarting:%d, number:%d, peer:%@", isStarting, num, peerName);
    if(!isStarting) 
    {
        if(num && peerName)
        {
            if(mOurMode == PARENT_OR_RECEIVER_MODE)
            {
                mBabyDeviceLabel.text = peerName;
            }
            else 
            {
                mParentDeviceLabel.text = peerName;
            }
        }
        
        [self setPairingStatus:DONE_LOOKING_FOR_DEVICES andWithInfo:[NSNumber numberWithInt:num]];
    }
    else
    {
        [self setPairingStatus:LOOKING_FOR_OTHER_DEVICES andWithInfo:nil];
    }
}

-(void) PMCIsConnectingWithPeer:(NSString*)currentlyConnectingToPeer
{
    mConnectButton.hidden = YES;
    mTryAgainButton.hidden = YES;
    mCancelButton.hidden = YES;
    
    mConnectionStatusLabel.text = @"Connecting...";
    
    UIImage* image = [UIImage imageNamed:@"PairingOngoing.png"];
    [mPairingStatusIconImageView setImage:image];

    CABasicAnimation *fullRotation;
    fullRotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
    fullRotation.fromValue = [NSNumber numberWithFloat:0];
    fullRotation.toValue = [NSNumber numberWithFloat:((360*M_PI)/180)];
    fullRotation.duration = 5.0f;
    fullRotation.repeatCount = MAXFLOAT;
    
    mPairingStatusIconImageView.hidden = NO;
    
    [mPairingStatusIconImageView.layer addAnimation:fullRotation forKey:@"NowPairing"];
}

-(void) PMCConnectionWithPeerEndedWithError:(BMErrorCode) error peerName:(NSString*) str
{
    
}

-(void) tryConnectionAfterResolve:(NSNetService *)netService
{
    if(mDelegate && [mDelegate respondsToSelector:@selector(tryConnectionAfterResolve:)])
    {
        [mDelegate tryConnectionAfterResolve:netService];
    }
}

-(void) setPairingStatus:(PairingStatus) newStatus andWithInfo:(id)info
{
    DDLogInfo(@"\nPairingStatusViewController: setPairingStatus with status %d", newStatus);
    
    switch (newStatus) 
    {
        case LOOKING_FOR_OTHER_DEVICES:
        {
            NSString* str = [NSString stringWithFormat:@"Looking for other Devices on the Network"];
            mConnectionStatusLabel.text = str;
            
            UIImage* image = [UIImage imageNamed:@"PairingOngoing.png"];
            [mPairingStatusIconImageView setImage:image];
            mPairingStatusIconImageView.hidden = NO;
            mConnectButton.hidden = YES;
            mCancelButton.hidden = YES;

                        
            CABasicAnimation *fullRotation;
            fullRotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
            fullRotation.toValue = [NSNumber numberWithFloat:0];
            fullRotation.fromValue = [NSNumber numberWithFloat:((360*M_PI)/180)];
            fullRotation.duration = 5.0f;
            fullRotation.repeatCount = MAXFLOAT;
            
            [mPairingStatusIconImageView.layer addAnimation:fullRotation forKey:@"NowPairing"];
        }
            break;
            
        case DONE_LOOKING_FOR_DEVICES:
        {
            NSNumber *nsnum = (NSNumber*) info;
            short num = [nsnum intValue];
            
            NSString* str = nil; 
                        
            [mPairingStatusIconImageView.layer removeAnimationForKey:@"NowPairing"];
            mPairingStatusIconImageView.hidden = YES;
            mCancelButton.hidden = YES;
            mTryAgainButton.hidden = YES;
            mConnectButton.hidden = NO;


            if(num)
            {
                if(mOurMode == PARENT_OR_RECEIVER_MODE)
                {
                    str = [NSString stringWithFormat:@"Would you like to use %@ to place near the baby?", mBabyDeviceLabel.text];
                    mBabyDeviceLabel.textColor = [UIColor blackColor];
                }
                else
                {
                    str = [NSString stringWithFormat:@"Would you like to use %@ to keep with you?", mParentDeviceLabel.text];
                    mParentDeviceLabel.textColor = [UIColor blackColor];
                }
                
                mConnectionStatusLabel.text = str;

                mConnectionStatusLabel.hidden = NO;
                [self addConnectButtonPressed];
            }
            else 
            {
                //[mPMCViewController stopSearchingForServices];

                if(mOurMode == PARENT_OR_RECEIVER_MODE)
                {
                    mBabyDeviceLabel.text = @"No Device(s) Found";
                    mBabyDeviceImage.alpha = .6;
                }
                else
                {
                    mParentDeviceLabel.text = @"No Device(s) Found";
                    mParentDeviceLabel.textColor = [UIColor redColor];
                    mParentDeviceImage.alpha = .6;
                }

                mConnectionStatusLabel.text = @"Please install and start the app on another device";
                mConnectionStatusLabel.hidden = NO;
                
                if([PersistentStorage isFirstTimeLaunch])
                {
                    [self addTryAgainTarget];
                }
                else
                {
                    [self addHideSelfTarget];
                }
            }
            
        }
            break;
            
        case CURRENTLY_PAIRING:
        {
            NSString* str = [NSString stringWithFormat:@"Attempting Connection with %@", 
                             (NSString*) info];
            mConnectionStatusLabel.text = str;
            
            CABasicAnimation *fullRotation;
            fullRotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
            fullRotation.fromValue = [NSNumber numberWithFloat:0];
            fullRotation.toValue = [NSNumber numberWithFloat:((360*M_PI)/180)];
            fullRotation.duration = 3.5f;
            fullRotation.repeatCount = MAXFLOAT;
            
            [mPairingStatusIconImageView.layer addAnimation:fullRotation forKey:@"NowPairing"];
            
            mConnectButton.hidden = YES;
            mCancelButton.hidden = YES;
        }
            break;
            
        case CURRENTLY_PAIRED:
        {
            [mPMCViewController stopSearchingForServices];

            [mPairingStatusIconImageView.layer removeAnimationForKey:@"NowPairing"];
            mPairingStatusIconImageView.hidden = YES;
            NSString* str = [NSString stringWithFormat:@"Connected. Ready to Start Monitoring."];
            mConnectionStatusLabel.text = str;
            
            mBabyDeviceImage.alpha = 1;

            [self addHideSelfTarget];
            
            mSwapButton.enabled = YES;
            
            mCancelButton.hidden = YES;
            mTryAgainButton.hidden = YES;

        }
            break;
            
        case PAIRING_FAILED:
        {
            [mPMCViewController stopSearchingForServices];

            [mPairingStatusIconImageView.layer removeAnimationForKey:@"NowPairing"];
            UIImage* image = [UIImage imageNamed:@"NotPaired.png"];
            
            [mPairingStatusIconImageView setImage:image];
            NSString* str = [NSString stringWithFormat:@"Failed to Connect with %@", 
                             (NSString*) info];
            mConnectionStatusLabel.text = str;
        }
            break;
            
        default:
            break;
    }

}

-(IBAction) tryAgainButtonPressed:(id)sender
{
    mTryAgainButton.hidden = YES;
    
    [self startLookupProcess];
}

-(IBAction) cancelButtonPressed:(id)sender
{
    [self hideSelf];
}

-(IBAction) swapModeButtonPressed
{
    if(mDelegate && [mDelegate respondsToSelector:@selector(userWantsToChangeMode)])
    {
        mSwapButton.enabled = NO;

        [mDelegate userWantsToChangeMode];
    }
}

-(void) connectButtonPressed
{
    DDLogInfo(@"\nSettingsViewController: Connect Button pressed");
    [mPMCViewController tryConnectingWithPeer];
}

-(IBAction) changePeerButtonPressed
{
    DDLogInfo(@"\nSettingsViewController: changePeerButtonPressed");
    NSString* peer = [PersistentStorage readPeerNameFromPersistentStorage];
    StateMachineStates state = [PersistentStorage readSMStateFromPersistentStorage];
    
    if(peer && ![StateMachine isAConnectedState:state])
    {
        NSString* title = [NSString stringWithFormat:@"%@ is not online.", peer];
                
        NSString* descptn = [NSString stringWithFormat:@"Would you like to connect to another device?"];
        
        mChangePeerAlertView = [[UIAlertView alloc] initWithTitle:title message:descptn
                                                         delegate:self
                                                cancelButtonTitle:@"No"
                                                otherButtonTitles:@"Yes", nil];
        [mChangePeerAlertView show];
    }
}

- (void)alertView : (UIAlertView *)alertView clickedButtonAtIndex : (NSInteger)buttonIndex
{
    //Alert: "Do you want to change peer's mode too"
    if(alertView == mChangePeerAlertView)
    {
        if(buttonIndex == 0)
        {
            DDLogInfo(@"\nStateMachine: Not Connecting to a different peer");
        }
        else if(buttonIndex == 1)
        {
           // DDLogInfo(@"\nStateMachine: Trying to connect to a different device");
            
            [self startLookupProcess];
        }
    }
    
    return;
}

-(void) hideSelf
{
    if(mDelegate && [mDelegate respondsToSelector:@selector(settingsViewControllerHasToClose)])
    {
        [mDelegate settingsViewControllerHasToClose];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupView];
    //[self addNavBar];
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
