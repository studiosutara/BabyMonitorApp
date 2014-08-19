//
//  PersistentStorage.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 7/20/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "PersistentStorage.h"
#import "DDLog.h"
const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation PersistentStorage


//
//  StateMachine+PersistentStorage.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 6/5/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"


+(NSString*) readPeerNameFromPersistentStorage
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
   
    if(!defaults)
    {
        DDLogInfo(@"\nPersistentStorage: readPeerNameFromPersistentStorage ERROR: No persistent storage");
        return nil;
    }
    
    NSString* savedPeerHostName = [defaults objectForKey:@"PeerHostName"];
    
    DDLogInfo(@"\nStateMachine: Saved Hostname: %@", savedPeerHostName);
    
    return savedPeerHostName;
}

+(NSString*) readPeerServiceNameFromPersistentStorage
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
   
    if(!defaults)
    {
        DDLogInfo(@"\nPersistentStorage: readPeerServiceNameFromPersistentStorage ERROR: No persistent storage");
        return nil;
    }

    NSString* savedPeerHostName = [defaults objectForKey:@"PeerServiceName"];
    
  //  DDLogInfo(@"\nStateMachine: Saved Servicename: %@", savedPeerHostName);
    
    return savedPeerHostName;
}

+(MonitorMode) readSMModeFromPersistentStorage
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if(!defaults)
    {
        DDLogInfo(@"\nPersistentStorage: readSMModeFromPersistentStorage ERROR: No persistent storage");
        return INVALID_MODE;
    }
    
    MonitorMode  savedMode = (MonitorMode)[defaults integerForKey:@"CurrentMode"];
    
 //   DDLogInfo(@"\nStateMachine: Saved Mode: %d", savedMode);
    
    return savedMode;
}

+(StateMachineStates) readSMStateFromPersistentStorage
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if(!defaults)
    {
        DDLogInfo(@"\nPersistentStorage: readSMStateFromPersistentStorage ERROR: No persistent storage");
        return STATE_INVALID;
    }
    
    StateMachineStates savedState = (StateMachineStates)[defaults integerForKey:@"CurrentState"];
    DDLogInfo(@"\nStateMachine: Saved State: %d", savedState);
    
    return savedState;
}

+(void) markFirstLaunchAsDone
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSInteger firsttime = (NSInteger)NotFirstTimeLaunch;
    [defaults setInteger:firsttime forKey:@"FirstTime"];
    
    [defaults synchronize];
}

+(bool) isFirstTimeLaunch
{
    // return YES;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  
    if(!defaults)
    {
    //    DDLogInfo(@"\nPersistentStorage: isFirstTimeLaunch ERROR: No persistent storage");
        return YES;
    }
    
    FirstTimeLaunchVals firsttime = (FirstTimeLaunchVals)[defaults integerForKey:@"FirstTime"];
    
    return (firsttime == FirstTimeLaunch);
}

#pragma clang diagnostic pop

@end
