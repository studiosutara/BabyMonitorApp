//
//  LaunchViewController.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 10/11/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol IntroScreenDelegate <NSObject>
-(void) closeIntroScreenAndLaunchHowItWorksScreen;
@end


@interface LaunchViewController : UIViewController
{
    __weak id <IntroScreenDelegate> mDelegate;

}

- (IBAction) continueButtonPressed: (id) sender;

@property (weak) IBOutlet UIButton *mcontinueButton;
@property (weak) IBOutlet UILabel*  mFirstLabel;
@property (weak) IBOutlet UILabel*  mSecondLabel;
@property (weak) IBOutlet UILabel*  mThirdLabel;
@property (weak) IBOutlet UILabel*  mFourthLabel;
@property (weak) IBOutlet UILabel*  mFifthLabel;
@property (weak) IBOutlet UILabel*  mSixthLabel;
@property (weak) IBOutlet UILabel*  mSeventhLabel;
@property (weak) IBOutlet UILabel*  mEighthLabel;


@property (weak) id <IntroScreenDelegate> mDelegate;

@end
