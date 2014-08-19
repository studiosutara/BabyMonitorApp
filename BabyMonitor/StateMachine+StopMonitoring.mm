//
//  StateMachine+StopMonitoring.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/25/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "StateMachine+StopMonitoring.h"
#import "DDLog.h"
#import "Utilities.h"

const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation StateMachine (StopMonitoring)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

- (BMErrorCode) userWantsToStopMonitoring:(bool) andSendStopPacket
{
    BMErrorCode error = BM_ERROR_NONE;
    
    if(self.mCurrentState != STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA && 
       self.mCurrentState != STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA)
    {
//        DDLogInfo(@"\nStateMachine: Stop Monitoring. SM not in expected state:%@", 
//              [mReadableStateTable objectAtIndex:self.mCurrentState]);
  
        if(self.mCurrentState == 
           STATE_WAITING_FOR_RESPONSE_FROM_PEER_TO_RESTART_OR_STOP_MONITORING)
        {
            if(self.mCurrentBabyMonitorMode == BABY_OR_TRANSMITTER_MODE)
            {
                error = [self StopMediaRecorder];
                if(error == BM_ERROR_NONE)
                {
                //    DDLogInfo(@"\nStateMachine: userWantsToStopMonitoring Stopped Media Recorder");
                }
                else 
                {
                    DDLogInfo(@"\nStateMachine: userWantsToStopMonitoring Error Stopping media recorder");
                }
            }
            else if(self.mCurrentBabyMonitorMode == PARENT_OR_RECEIVER_MODE)
            {
                error = [self StopMediaPlayer];
                if(error == BM_ERROR_NONE)
                {
                //    DDLogInfo(@"\nStateMachine: userWantsToStopMonitoring Stopped Media Recorder");
                }
                else 
                {
                    DDLogInfo(@"\nStateMachine: userWantsToStopMonitoring Error Stopping media recorder");
                }
            }
        
            [mProtocolManager shutdownControlStreams];
            [self disconnectComplete];
        }
        
        return BM_ERROR_NONE;
    }
    
    error = [Utilities deactivateAudioSession];
    if(error != BM_ERROR_NONE)
    {
     //   DDLogInfo(@"\nBMVC: Error deactiviating audioSession");
        return BM_ERROR_NONE;
    }

   //if we are the receiver, then ask the transmitter to stop monitoring.
    //we will go ahead and ask the mediaplayer to stop what it's doing
    if(self.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA)
    {
        @synchronized(self)
        {
            //we will go ahead and stop playing media irrespective of the result of the above action
            error = [self StopMediaPlayer];
            if(error != BM_ERROR_NONE)
            {
                DDLogInfo(@"\nStateMachine: error, media player unable to stop playing");
            }
            else 
            {
            //    DDLogInfo(@"\nStateMachine:userWantsToStopMonitoring Media Player Stopped");
                self.mCurrentState = STATE_CONNECTED_TO_PEER;
            }
        }
    }
    //else if we are the transmitter, we let the receiver know that we are going
    //to stop tx'ing and ask the mediarecorder to stop recording
    else if(self.mCurrentState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA)
    {
        @synchronized(self)
        {
            if([self StopMediaRecorder] !=BM_ERROR_NONE)
            {
                DDLogInfo(@"\nStateMachine: Error in stopping recorder");
            }
            else 
            {
            //    DDLogInfo(@"\nStateMachine: Stopped media Player");
                self.mCurrentState = STATE_CONNECTED_TO_PEER;
            }
        }
    }
    
    if(mDelegate && [mDelegate respondsToSelector:@selector(monitoringStatusChanged:)])
    {
        [mDelegate monitoringStatusChanged:NO];
    }

    if(andSendStopPacket)
    {
        //the the stop monitoring packet and send
      //  DDLogInfo(@"\nPM: Sent CONTROL_PACKET_TYPE_STOP_MONITORING packet");
        return [self.mProtocolManager getPacketAndSendOfType:CONTROL_PACKET_TYPE_STOP_MONITORING 
                                   andError:BM_ERROR_NONE];
    }
    
    return BM_ERROR_NONE;
}

-(BMErrorCode) receivedPauseMonitoringPacketFromPeer
{
    BMErrorCode error = [self StopPlayingOrRecording];
    
    if(error == BM_ERROR_NONE)
    {
    //    DDLogInfo(@"\nStateMachine: Stopped Media Player/Recorder successfully on interrupt");
        @synchronized(self)
        {
            self.mCurrentState = STATE_PEER_PAUSED_ON_INTERRUPT;
            [self writeToPersistentStrorage];
        }
    }
    else 
    {
        DDLogInfo(@"\nStateMachine: Error Stopping Media Player/Recorder after interrupt");
    }
       
    
    if(mDelegate && [mDelegate respondsToSelector:@selector(monitoringStatusChanged:)])
    {
        [mDelegate monitoringStatusChanged:NO];
    }

    return error;
}

-(BMErrorCode) receivedStopMonitoringPacketFromPeer
{
    BMErrorCode error = [Utilities deactivateAudioSession];
    if(error != BM_ERROR_NONE)
    {
        DDLogInfo(@"\nStateMachine: Error deactiviating audioSession");
        return BM_ERROR_NONE;
    }
    else
     //   DDLogInfo(@"\nStateMachine: AudioSession Deactivated");

    
     error = [self StopPlayingOrRecording];
    
    if(error == BM_ERROR_NONE)
    {
       // DDLogInfo(@"\nStateMachine: Stopped Media Player/Recorder successfully on STOP MON");
        self.mCurrentState = STATE_CONNECTED_TO_PEER;
        [self writeToPersistentStrorage];
    }
    else 
    {
     //   DDLogInfo(@"\nStateMachine: Error Stopping Media Player after STOP MON packet");
    }
    
    
    if(mDelegate && [mDelegate respondsToSelector:@selector(monitoringStatusChanged:)])
    {
        [mDelegate monitoringStatusChanged:NO];
    }

    return error;
}

-(BMErrorCode) StopPlayingOrRecording
{
    BMErrorCode error = BM_ERROR_NONE;
    if(self.mCurrentState == STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA)
    {
        error = [self StopMediaPlayer];
        if(error == BM_ERROR_NONE)
        {
            DDLogInfo(@"\nStateMachine: Error Media Player stopped");
        }
        else 
        {
          //  DDLogInfo(@"\nStateMachine: Error stopping Media Player");
        }
    }
    else if(self.mCurrentState == STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA)
    {
        error = [self StopMediaRecorder];
        if(error == BM_ERROR_NONE)
        {
         //   DDLogInfo(@"\nStateMachine: Media Recorder stopped");
        }
        else 
        {
            DDLogInfo(@"\nStateMachine: Error stopping Media Recorder");
        }
    }
    
    return error;
}

-(BMErrorCode) receivedStopMonitoringACKPacketFromPeer
{
   // DDLogInfo(@"\nStateMachine: receivedStopMonitoringACKPacketFromPeer");
    if(self.mCurrentState == STATE_WAITING_FOR_DISCONNECT_ACK_TO_FINISH_DISCONNECTING)
    {
        [self completeUserDisconnectWithPeerAfterACKWasReceived];
    }
    
    return BM_ERROR_NONE;
}

#pragma clang diagnostic pop
@end
