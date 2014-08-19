//
//  HowItWorksScreenViewController.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 9/11/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "HowItWorksScreenViewController.h"

@interface HowItWorksScreenViewController ()

@end

@implementation HowItWorksScreenViewController

@synthesize mcontinueButton;
@synthesize mFirstLabel;
@synthesize mSecondLabel;
@synthesize mThirdLabel;
@synthesize mDelegate;

-(IBAction) continueButtonPressed:(id) sender
{ 
    if (self.mDelegate && 
        [self.mDelegate respondsToSelector:@selector(closeHowItWorksScreenAndLaunchTheSettingsScreen)])
    {
        [self.mDelegate closeHowItWorksScreenAndLaunchTheSettingsScreen];
    }
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
 //   mFirstLabel.font = [UIFont fontWithName:@"Sansation" size:26];
    mSecondLabel.font = [UIFont fontWithName:@"Sansation" size:16];
    mThirdLabel.font = [UIFont fontWithName:@"Sansation" size:16];

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
