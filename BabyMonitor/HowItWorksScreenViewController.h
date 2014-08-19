//
//  HowItWorksScreenViewController.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 9/11/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol HowItWorksScreenDelegate <NSObject>
-(void) closeHowItWorksScreenAndLaunchTheSettingsScreen;
@end

@interface HowItWorksScreenViewController : UIViewController
{
    __weak id <HowItWorksScreenDelegate> mDelegate;
}

- (IBAction) continueButtonPressed: (id) sender;

@property (weak) IBOutlet UIButton *mcontinueButton;
@property (weak) IBOutlet UILabel*  mFirstLabel;
@property (weak) IBOutlet UILabel*  mSecondLabel;
@property (weak) IBOutlet UILabel*  mThirdLabel;

@property (weak) id <HowItWorksScreenDelegate> mDelegate;

@end
