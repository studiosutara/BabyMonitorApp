//
//  StateMachine+PersistentStorage.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 6/5/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "StateMachine+PersistentStorage.h"
#import "DDLog.h"
const int ddLogLevel = LOG_LEVEL_VERBOSE;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation StateMachine (PersistentStorage)

-(void) writeToPersistentStrorage
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setInteger:mCurrentState forKey:@"CurrentState"];
    [defaults setInteger:mCurrentBabyMonitorMode forKey:@"CurrentMode"];
    
    if(mPeerManager.mCurrentPeerHostName)
        [defaults setObject:mPeerManager.mCurrentPeerHostName forKey:@"PeerHostName"];
    else
        DDLogInfo(@"\nwriteToPersistentStrorage: peer name is null");
    
    [defaults setObject:mPeerServiceName forKey:@"PeerServiceName"];
    
    [defaults synchronize];
    
   /* DDLogInfo(@"\n----------------------------------");
    DDLogInfo(@"\nStateMachine: Saving the app state");
    DDLogInfo(@"HostName = %@  ", mPeerManager.mCurrentPeerHostName);
    DDLogInfo(@"Mode = %d  ", self.mCurrentBabyMonitorMode);
    DDLogInfo(@"State = %d", self.mCurrentState);
    DDLogInfo(@"\n----------------------------------");*/

}

-(void) writeStateToPersistentStrorage
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:mCurrentState forKey:@"CurrentState"];

    [defaults synchronize];

    DDLogInfo(@"\nStateMachine:writeStateToPersistentStrorage = %d", self.mCurrentState);
}

-(void) writeModeToPersistentStrorage
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:mCurrentBabyMonitorMode forKey:@"CurrentMode"];
    
    [defaults synchronize];
    
  //  DDLogInfo(@"\nStateMachine:writeModeToPersistentStrorage = %d", self.mCurrentBabyMonitorMode);
}

-(void) writePeerNameToPersistentStrorage
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if(mPeerManager.mCurrentPeerHostName)
    {    [defaults setObject:mPeerManager.mCurrentPeerHostName forKey:@"PeerHostName"];
        [defaults setObject:mPeerServiceName forKey:@"PeerServiceName"];
    }
//    else
//        DDLogInfo(@"\nwriteToPersistentStrorage: peer name is null");

    [defaults synchronize];
    
 //   DDLogInfo(@"\nStateMachine:writePeerNameToPersistentStrorage = %@ and %@", mPeerManager.mCurrentPeerHostName, mPeerServiceName);
}

-(void) readFromPersistentStorage
{
 //   DDLogInfo(@"\nStateMachine: Reading the app state");
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
   // StateMachineStates savedState = (StateMachineStates)[defaults integerForKey:@"CurrentState"];
    //MonitorMode  savedMode = (MonitorMode)[defaults integerForKey:@"CurrentMode"];
    NSString* savedPeerHostName = [defaults objectForKey:@"PeerHostName"];
    mPeerServiceName = [defaults objectForKey:@"PeerServiceName"];
    
    self.mPeerManager.mCurrentPeerHostName = savedPeerHostName;
    
   /* DDLogInfo(@"\nStateMachine: Saved State: %@", [mReadableStateTable objectAtIndex:savedState]);
    DDLogInfo(@"\nStateMachine: Saved Mode: %d", savedMode);
    DDLogInfo(@"\nStateMachine: Saved Hostname: %@", savedPeerHostName);
    DDLogInfo(@"\nStateMachine: Saved Host Servicename = %@", mPeerServiceName);*/
}

#pragma clang diagnostic pop

@end
