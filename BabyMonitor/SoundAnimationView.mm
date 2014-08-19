//
//  SoundAnimationView.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 7/3/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "SoundAnimationView.h"
#import "CAStreamBasicDescription.h"
#import "DDLog.h"

const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation SoundAnimationView

@synthesize mUpdateTimer;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) 
    {
    }

    return self;
}

- (AudioQueueRef) mAudioQueue 
{ 
    return mAudioQueue; 
}

-(void) initViews
{
    self.backgroundColor = [UIColor clearColor];

    //self.hidden = YES;
    mPearlCollection =  [[NSArray alloc] initWithObjects:
                         mImage1, mImage2, mImage3, mImage4, mImage5, mImage6, mImage7,
                         mImage8, mImage9, mImage10, mImage11, mImage12,
                         nil];
    
    
    for (int i= 0; i<[mPearlCollection count]; i++) 
    {
        UIImageView* imageV = (UIImageView*)[mPearlCollection objectAtIndex:i];
        imageV.alpha = 0.2;
    }

}
  
-(void) stopAnimation
{
    //DDLogInfo(@"SoundAnimation: Stopping animation");
    for (int i= 0; i<[mPearlCollection count]; i++) 
    {
        UIImageView* imageV = (UIImageView*)[mPearlCollection objectAtIndex:i];
        imageV.alpha = 0.2;
    }
    
   //self.hidden = YES;
    
    if (mUpdateTimer)
        [mUpdateTimer invalidate];
    
    mAudioQueue = nil;
}

- (void)setMAudioQueue:(AudioQueueRef)newQueue
{	
    // Initialization code
    //DDLogInfo(@"SoundAnimation: setting audio queue");
    self.hidden = NO;
    mMeterTable = new MeterTable(kMinDBvalue);
    
    mChannelLevel = (AudioQueueLevelMeterState*) malloc(sizeof(AudioQueueLevelMeterState));

    mRefreshHz = 1. / 3.;
    
	if ((mAudioQueue == NULL) && (newQueue != NULL))
	{
		if (mUpdateTimer) 
            [mUpdateTimer invalidate];
		
		mUpdateTimer = [NSTimer 
						scheduledTimerWithTimeInterval:mRefreshHz 
						target:self 
						selector:@selector(_refresh) 
						userInfo:nil 
						repeats:YES
						];
        
	} 
    else if ((mAudioQueue != NULL) && (newQueue == NULL)) 
    {
		mPeakFalloffLastFire = CFAbsoluteTimeGetCurrent();
	}
	
	mAudioQueue = newQueue;
	if (mAudioQueue)
	{
		UInt32 val = 1;
        OSStatus err = AudioQueueSetProperty(mAudioQueue, 
                              kAudioQueueProperty_EnableLevelMetering,
                              &val, 
                              sizeof(UInt32));
        
        if(err != noErr)
        {
            NSLog(@"\nError enabling level metering");
        }
    }   
}

- (CGFloat)mRefreshHz 
{ 
    return mRefreshHz; 
}

- (void)setMRefreshHz:(CGFloat)newVal
{
    
	mRefreshHz = newVal;
	if (mUpdateTimer)
	{
		[mUpdateTimer invalidate];
		/*mUpdateTimer = [NSTimer
						scheduledTimerWithTimeInterval:mRefreshHz 
						target:self 
						selector:@selector(_refresh) 
						userInfo:nil 
						repeats:YES
						];*/
	}
}

- (void)_refresh
{
	BOOL success = NO;
   // DDLogInfo(@"\nSoundAnimation: refreshing...");
    
	// if we have no queue, but still have levels, gradually bring them down
	if (mAudioQueue == NULL)
	{
		CGFloat maxLvl = -1.;
		CFAbsoluteTime thisFire = CFAbsoluteTimeGetCurrent();
		// calculate how much time passed since the last draw
		CFAbsoluteTime timePassed = thisFire - mPeakFalloffLastFire;
		
        //CGFloat newPeak;
        CGFloat newLevel;
        newLevel = mLevel - timePassed * kLevelFalloffPerSec;
        if (newLevel < 0.) newLevel = 0.;
        mLevel = newLevel;
       
//        newPeak = mPeakLevel - timePassed * kPeakFalloffPerSec;
//        if (newPeak < 0.) 
//            newPeak = 0.;
//
//        mPeakLevel = newPeak;
//        if (newPeak > maxLvl) maxLvl = newPeak;
        
        if (newLevel > maxLvl) maxLvl = newLevel;
       
		if (maxLvl <= 0.)
		{
			[mUpdateTimer invalidate];
			mUpdateTimer = nil;
		}
		
        [self redrawPearls];
		mPeakFalloffLastFire = thisFire;
		success = YES;
	} 
    else 
    {
		UInt32 data_sz = sizeof(AudioQueueLevelMeterState);
		OSErr status = AudioQueueGetProperty(mAudioQueue, 
                                             kAudioQueueProperty_CurrentLevelMeterDB, 
                                             mChannelLevel, 
                                             &data_sz);
		if (status != noErr) 
            goto bail;
        
	    //DDLogInfo(@"\nAQMeter: refresh: number od channels are: %d", [_channelNumbers count]);
        if (mChannelLevel)
        {
            mLevel = mMeterTable->ValueAt((float)(mChannelLevel->mAveragePower));
            mPeakLevel = mMeterTable->ValueAt((float)(mChannelLevel->mPeakPower));
           
            if(!mLevel)
            {
                //DDLogInfo(@"\nSounfAnimation, no sound");
            }
            [self redrawPearls];
            success = YES;
        }
    }
	
bail:
	
	if (!success)
	{
        mLevel = 0.; 
        [self redrawPearls]; 
    }
		
  //  DDLogInfo(@"ERROR: metering failed\n");
}

-(void) redrawPearls
{
    int light_i;
    CGFloat lightMinVal = 0.;
    
    int peakLight = -1;
    if (mPeakLevel > 0.)
    {
        peakLight = mPeakLevel * [mPearlCollection count];
        if (peakLight >= [mPearlCollection count]) 
            peakLight = [mPearlCollection count] - 1;
    }
    
    //for (light_i=0; light_i<([mPearlCollection count]/2); light_i++)
    for (light_i=0; light_i<[mPearlCollection count]; light_i++)
    {        
        //DDLogInfo(@"\nRedraw pearls: i =%d", light_i);
        
        UIImageView* imageI = [mPearlCollection objectAtIndex:light_i];

        CGFloat lightMaxVal = (CGFloat)(light_i + 1) / (CGFloat)[mPearlCollection count];
        CGFloat lightIntensity;
        
//        if (light_i == peakLight)
//        {
//            lightIntensity = 1.;
//        } 
//        else 
        {
            lightIntensity = (mLevel - lightMinVal) / (lightMaxVal - lightMinVal);
            lightIntensity = LEVELMETER_CLAMP(0., lightIntensity, 1.);
        }
        
       imageI.alpha = lightIntensity;
       lightMinVal = lightMaxVal;
    }		

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
