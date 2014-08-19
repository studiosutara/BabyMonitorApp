//
//  SlideOutAttentionView.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 9/24/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "SlideOutAttentionView.h"
#import <QuartzCore/QuartzCore.h>

@implementation SlideOutAttentionView
@synthesize mInfoLabel;
@synthesize mBatteryInfoLabel;
@synthesize mSilenceInfoLabel;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        // Initialization code
    }
    return self;
}

-(void) setupView
{
    // Initialization code
//    self.mInfoLabel.textColor = [UIColor grayColor];
//    self.mBatteryInfoLabel.textColor = [UIColor grayColor];
//    self.mSilenceInfoLabel.textColor = [UIColor grayColor];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
