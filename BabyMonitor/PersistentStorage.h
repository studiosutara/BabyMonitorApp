//
//  PersistentStorage.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 7/20/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BMUtility.h"
#import "StateMachine.h"

typedef enum
{
    FirstTimeLaunch =0,
    NotFirstTimeLaunch =1
}FirstTimeLaunchVals;


@interface PersistentStorage : NSObject
{
    
}

+(NSString*) readPeerNameFromPersistentStorage;

+(MonitorMode) readSMModeFromPersistentStorage;

+(StateMachineStates) readSMStateFromPersistentStorage;

+(NSString*) readPeerServiceNameFromPersistentStorage;

+(void) markFirstLaunchAsDone;

+(bool) isFirstTimeLaunch;

@end
