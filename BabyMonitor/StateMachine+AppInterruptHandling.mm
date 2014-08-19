//
//  StateMachine+AppInterruptHandling.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 5/17/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "StateMachine+AppInterruptHandling.h"
#import <CoreTelephony/CTCall.h>
#import "PersistentStorage.h"
#import "DDLog.h"
const int ddLogLevel = LOG_LEVEL_VERBOSE;


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"


@implementation StateMachine (AppInterruptHandling)

-(void) printAppState
{
    DDLogInfo(@"\n--------------------------PRINT APP STATE START--------------------");
    DDLogInfo(@"\nStateMachine: State = %d", self.mCurrentState);
    if(self.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA)
    {
        [self.mMediaPlayer.mAQPlayer printState];
    }
    else if(self.mCurrentState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA)
    {
        [self.mMediaRecorder.mAQRecorder printState];
    }
    
    DDLogInfo(@"\n\n--------------------------PRINT APP STATE END--------------------");

}

-(BMErrorCode) peerWantsToPauseOnInterrupt
{
    BMErrorCode error = BM_ERROR_NONE;
    //Treat this exactly like you would a STOP_MON packet
  //  DDLogInfo(@"\nStateMachine: peerWantsToPauseOnInterrupt");
    
    error = [self receivedPauseMonitoringPacketFromPeer];
    if(error != BM_ERROR_NONE)
    {
        DDLogInfo(@"\nStateMachine: Received pause-on-interrupt packet, but error stoppping mon");
    }
    
    return error;
}

//-(bool) areWeCurrentlyInCall
//{
//    CTCall.callState 
//}
//

-(BMErrorCode) handleAppWillGoToBackground:(bool) isCallActive
{
    BMErrorCode error = BM_ERROR_NONE;
  //  DDLogInfo(@"\nStateMachine: handleAppWillGoToBackground in state %@",
    //          [mReadableStateTable objectAtIndex:self.mCurrentState]);

    if(!isCallActive && 
       (self.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA || 
        self.mCurrentState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA ||
       self.mCurrentState == STATE_WAITING_FOR_RESPONSE_FROM_PEER_TO_RESTART_OR_STOP_MONITORING||
       self.mCurrentState == STATE_LOST_WIFI_CONNECTION_WHILE_MONITORING))
    {
        return BM_ERROR_NONE;
    }
    
    //TODO : handle the talk to baby mode here too
    
    //=======================================================
    //1. disable bonjour for all the cases
    //=======================================================
    [self.mPeerManager.mPeerManagerServer disableBonjour];
        
    //=======================================================
    //2. do whatever else needs to be done
    //=======================================================
    switch (mCurrentState) 
    {
        case STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA:
        case STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA:
        {
            //2. send the pause packet to the peer
            error = [self.mProtocolManager getPauseOnInterruptPacketAndSend];
            if(error != BM_ERROR_NONE)
            {
                //Do not return here, go ahead and finish the rest of the functionality
                DDLogInfo(@"\nStateMachine: error sending the PAUSE_ON_INTERRUPT packet to peer");
            }
            else 
            {
      //          DDLogInfo(@"\nStateMachine: Sent PAUSE ON INTERRUPT PACKET");
            }
            
            if(isCallActive)
            {
                //stop monitoring
                //When we resume we want to stop all and restart monitoring
                if(self.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA)
                {
                    [self.mMediaPlayer stopMediaStreamActivityWatchTimer];
                    [self StopMediaPlayer];
                }
                else if(self.mCurrentState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA)
                {
                    [self.mMediaRecorder stopMediaStreamActivityWatchTimer];
                    [self StopMediaRecorder];
                }
                
                self.mCurrentState = STATE_STOPALL_AND_RESTART_MONITORING;
            }
            else 
            {
                //if we are going to background for any other reason, then we should just 
                //connect back to this peer after we resume, no need to restart monitoring
                self.mCurrentState = STATE_CONNECTED_TO_PEER;
            }
        }
            break;
            
            case STATE_CONNECTED_TO_PEER:
        {
            //we are currently connected to the peer, but we are  not actively monitoring
                //save state as connected to peer
            [self.mProtocolManager shutdownControlStreams];
                //peer will notice us going offline and disconnect itself
        }
            break;
            
        case STATE_STOPALL_AND_RESTART_MONITORING:
            //do nothing here, we are already in the needed state
            break;
            
        default:
        {
            //we will treat all other cases as not connected to the peer- save this state 
            //disconnect and shutdown streams if any are open
            self.mCurrentState = STATE_INITIALIZED;
        }
            break;
    }
    
    //=======================================================
    //3. save all of the latest state to persitent storage 
    //=======================================================
    //write the current state to persistent storage
        //if we were interrupted by a call - the state should indicate that
    //write the current mode to persistent storage
    //write the info about the peer we are currently connected to
    [self writeToPersistentStrorage];
    
    return error;
}

-(BMErrorCode) handleReconnectAfterComingToForeground
{
    BMErrorCode error = BM_ERROR_NONE;
    DDLogInfo(@"\nStateMachine:handleReconnectAfterComingToForeground");
    
    //if we have a peer on file then we must've been previously connected to it
    //go ahead and re-do the connection here
    self.mPeerManager.mCurrentPeerHostName = [PersistentStorage readPeerNameFromPersistentStorage];
    if(self.mPeerManager.mCurrentPeerHostName && [self.mPeerManager isPeerOnline])
    {
        self.mCurrentState = STATE_WAITING_FOR_NETSERVER_TO_PUBLISH_TO_RESUME_CONNECTING;
    }
    //else we must've done an explicit disconnect, do nothing here
    else 
    {
        @synchronized(self)
        {
            self.mCurrentState = STATE_INITIALIZED;
            [self writeStateToPersistentStrorage];
        }
        
        if(self.mDelegate && [self.mDelegate respondsToSelector:@selector(connectionStatusChanged:withPeer:isIncoming:)])
        {
            [self.mDelegate connectionStatusChanged:NO withPeer:nil isIncoming:NO];
        }
    }
    
    return error;
}

-(BMErrorCode) handleAppWillComeToForeground
{
    BMErrorCode error = BM_ERROR_NONE;
    
//    DDLogInfo(@"\nStateMachine: handleAppWillComeToForeground in state %@", 
//          [mReadableStateTable objectAtIndex:self.mCurrentState]);
    
    if(self.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA || 
       self.mCurrentState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA||
       self.mCurrentState == STATE_PARENTMODE_TALKING_TO_BABY ||
       self.mCurrentState == STATE_BABYMODE_LISTENING_TO_PARENT)
    {
        if([self.mProtocolManager areControlStreamsSetup])
        {
//            DDLogInfo(@"\nStateMachine:Coming to foreground after having been in background. \
//                      We are actively monitoring, so nothing to do");
            return BM_ERROR_NONE;
        }
    }
    //Read the saved state from the persistent memory
    StateMachineStates initState = STATE_INVALID;
    initState = [PersistentStorage readSMStateFromPersistentStorage];

    //Read the mode
    self.mCurrentBabyMonitorMode = [PersistentStorage readSMModeFromPersistentStorage];

    if(self.mCurrentState != STATE_INVALID)
        [self start];

    if(initState == STATE_STOPALL_AND_RESTART_MONITORING)
    {
        error = [self restartMonitoringAfterInterrupt];
    }
    else
    {
       error = [self handleReconnectAfterComingToForeground];
    }
    
    //=========================================================
    //Enable bonjour irrespective of the previous states 
    //=========================================================
    //re-enable bonjour
    if(![self.mPeerManager.mPeerManagerServer enableBonjourWithDomain:@"local" 
                                                  applicationProtocol:[Utilities getBonjourType] 
                                                                 name:nil]) 
    {
        DDLogInfo(@"\nStateMachine: Failed advertising server");
    }
    
    return error;
}

-(BMErrorCode) restartMonitoringAfterInterrupt
{
    BMErrorCode error = BM_ERROR_NONE;
    
   // DDLogInfo(@"\nStateMachine: restartMonitoringAfterInterrupt");
    error = [self.mPeerManager checkConnectionWithPeer];
    
    if(error != BM_ERROR_NONE) 
    {
        DDLogInfo(@"\nStateMachine: Cannot resume monitoring, the peer seems to be offline");
        return BM_ERROR_NONE;
    }
    
    if(mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE)
    {
        @synchronized(self)
        {
           /* if([self StopMediaRecorder] != BM_ERROR_NONE)
            {
                DDLogInfo(@"\nStateMachine: Error in stopping recorder");
            }
            else */
            {
               // DDLogInfo(@"\nStateMachine: restartMonitoringAfterInterrupt. Stopped Media Recoder, waiting for service to publish");
                self.mCurrentState = STATE_WAITING_FOR_NETSERVER_TO_PUBLISH_TO_RESUME_MONITORING;
            }
        }
    }
    else if(mCurrentBabyMonitorMode == PARENT_OR_RECEIVER_MODE)
    {
        @synchronized(self)
        {
            //we will go ahead and stop playing media irrespective of the result of the above action
           /* error = [self StopMediaPlayer];
            if(error != BM_ERROR_NONE)
            {
                DDLogInfo(@"\nStateMachine: error, media player unable to stop playing");
            }
            else */
            {
                DDLogInfo(@"\nStateMachine: restartMonitoringAfterInterrupt Stopped Media Player. Waiting for service to publish");
                self.mCurrentState = STATE_WAITING_FOR_NETSERVER_TO_PUBLISH_TO_RESUME_MONITORING;
            }
        }
    }
    
    return error;
}

-(void) completeResumeMonitor
{
    self.mCurrentState = STATE_CONNECTED_TO_PEER;
    [self writeStateToPersistentStrorage];
    [self userWantsToStartMonitoring];
}

-(BMErrorCode) peerWantsToResumeAfterInterrupt
{
    
    return BM_ERROR_NONE;
}

#pragma clang diagnostic pop

@end
