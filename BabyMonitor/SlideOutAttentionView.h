//
//  SlideOutAttentionView.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 9/24/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SlideOutAttentionView : UIView
{
    
}

@property IBOutlet UILabel* mInfoLabel;
@property IBOutlet UILabel* mBatteryInfoLabel;
@property IBOutlet UILabel* mSilenceInfoLabel;

-(void) setupView;
@end
