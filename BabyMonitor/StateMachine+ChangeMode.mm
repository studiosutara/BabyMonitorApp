//
//  StateMachine+ChangeMode.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 5/3/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "StateMachine+ChangeMode.h"
#import "DDLog.h"
const int ddLogLevel = LOG_LEVEL_VERBOSE;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"


@implementation StateMachine (ChangeMode)

-(BMErrorCode) peerWantsToToggleMode
{
    UIAlertView *alertView = nil;
    NSString* desc = nil;
    NSString* title = nil;
    BMErrorCode error = BM_ERROR_NONE;
    
    if(mCurrentState == STATE_CONNECTED_TO_PEER)
    {
      //  DDLogInfo(@"\nStateMachine: Changing self mode");
        @synchronized(self)
        {
            self.mCurrentBabyMonitorMode = (self.mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE) ? 
            PARENT_OR_RECEIVER_MODE : BABY_OR_TRANSMITTER_MODE;
            
            [self writeModeToPersistentStrorage];
        }

        
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSMToBMVCSMModeChanged                                                            object:[NSNumber numberWithInt:self.mCurrentBabyMonitorMode]]; 

    }
    else 
    {
        DDLogInfo(@"\nStateMachine: attempting to chnge mode in the wrong SM state");
        desc = [NSString stringWithFormat:@"Cannot change mode as requested by peer"];
        title = @"Error";

        alertView = [[UIAlertView alloc] initWithTitle:title 
                                               message:desc
                                              delegate:self 
                                     cancelButtonTitle:@"OK" 
                                     otherButtonTitles:nil];
        [alertView show];
        
        error = BM_ERROR_SM_NOT_IN_EXPECTED_STATE;
    }
    
    return error;
}

-(BMErrorCode) userToggledMode
{
    DDLogInfo(@"\nStateMachine: userToggledMode");
        
    if(mCurrentState == STATE_CONNECTED_TO_PEER)
    {
        @synchronized(self)
        {
            self.mCurrentBabyMonitorMode = (self.mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE) ? 
            PARENT_OR_RECEIVER_MODE : BABY_OR_TRANSMITTER_MODE;
            
            [self writeModeToPersistentStrorage];
        }
        
        [self.mProtocolManager getChangeModePacketAndSend];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationSMToBMVCSMModeChanged
                                                            object:[NSNumber numberWithInt:self.mCurrentBabyMonitorMode]];
    }
    else 
    {
        DDLogInfo(@"\nStateMachine: Error: unable to change the mode in this state %d", self.mCurrentState);
        return  BM_ERROR_SM_NOT_IN_EXPECTED_STATE;
    }
    
    return BM_ERROR_NONE;
}

- (void)alertView : (UIAlertView *)alertView clickedButtonAtIndex : (NSInteger)buttonIndex
{
    //Alert: "Do you want to change peer's mode too"
    if(alertView == mTogglePeerModeAlert)
    {
        if(buttonIndex == 0)
        {
            DDLogInfo(@"\nStateMachine: Not changing the peer device mode");
        }
        else if(buttonIndex == 1)
        {
            [self.mProtocolManager getChangeModePacketAndSend];
            
          //  DDLogInfo(@"\nStateMachine: Changing the peer device mode");
        }
    }
 
    return;
}

#pragma clang diagnostic pop

@end
