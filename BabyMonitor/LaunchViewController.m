//
//  LaunchViewController.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 10/11/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "LaunchViewController.h"
#import "DDLog.h"

@interface LaunchViewController ()

@end

@implementation LaunchViewController

@synthesize mcontinueButton;
@synthesize mDelegate;
@synthesize mFirstLabel;
@synthesize mSecondLabel;
@synthesize mThirdLabel;
@synthesize mFourthLabel;
@synthesize mFifthLabel;
@synthesize mSixthLabel;
@synthesize mSeventhLabel;
@synthesize mEighthLabel;


-(IBAction) continueButtonPressed:(id) sender
{
    if (self.mDelegate &&
        [self.mDelegate respondsToSelector:@selector(closeIntroScreenAndLaunchHowItWorksScreen)])
    {
        [self.mDelegate closeIntroScreenAndLaunchHowItWorksScreen];
    }
}

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

-(void)viewDidLoad
{
    [super viewDidLoad];
    //AmaticSC-Bold
    mFirstLabel.font = [UIFont fontWithName:@"Sansation" size:22];
    mSecondLabel.font = [UIFont fontWithName:@"Sansation" size:15];
    mThirdLabel.font = [UIFont fontWithName:@"Sansation" size:24];
    mFourthLabel.font = [UIFont fontWithName:@"Sansation" size:18];
    mFifthLabel.font = [UIFont fontWithName:@"Sansation" size:24];
    mSixthLabel.font = [UIFont fontWithName:@"Sansation" size:18];
    mSeventhLabel.font = [UIFont fontWithName:@"Sansation" size:24];
    mEighthLabel.font = [UIFont fontWithName:@"Sansation" size:24];
    mEighthLabel.textColor = [UIColor redColor];
    
    //mFirstLabel.textColor = [UIColor darkGrayColor];
    // Do any additional setup after loading the view from its nib.
}

-(void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
