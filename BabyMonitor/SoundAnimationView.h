//
//  SoundAnimationView.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 7/3/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <AudioToolbox/AudioToolbox.h>
#import "MeterTable.h"

#define kPeakFalloffPerSec	.7
#define kLevelFalloffPerSec .8
#define kMinDBvalue -80.0

#ifndef LEVELMETER_CLAMP
#define LEVELMETER_CLAMP(min,x,max) (x < min ? min : (x > max ? max : x))
#endif

static const unsigned int TOTAL_NUMBER_OF_PEARLS=11;


@interface SoundAnimationView : UIView
{
    NSArray* mPearlCollection;
    IBOutlet UIImageView* mCenterPearl;
    
    IBOutlet UIImageView* mImage1;
    IBOutlet UIImageView* mImage2;
    IBOutlet UIImageView* mImage3;
    IBOutlet UIImageView* mImage4;
    IBOutlet UIImageView* mImage5;
    IBOutlet UIImageView* mImage6;
    IBOutlet UIImageView* mImage7;
    IBOutlet UIImageView* mImage8;
    IBOutlet UIImageView* mImage9;
    IBOutlet UIImageView* mImage10;
    IBOutlet UIImageView* mImage11;
    IBOutlet UIImageView* mImage12;
    
    AudioQueueRef		  mAudioQueue;
    NSTimer*			  mUpdateTimer;
    CGFloat				  mRefreshHz;

	CFAbsoluteTime		  mPeakFalloffLastFire;

	CGFloat				  mLevel, mPeakLevel;
    
    AudioQueueLevelMeterState*	mChannelLevel;

    MeterTable*					mMeterTable;

}

-(void) initViews;
-(void) stopAnimation;

@property AudioQueueRef mAudioQueue; // The AudioQueue object
@property NSTimer*			  mUpdateTimer;
@property CGFloat       mRefreshHz;

@end
