//
//  StateMachine+ProtocolManagerDelegate.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/25/12.
//  Copyright (c) 2012 Studio Sutara LLC. All rights reserved.
//

#import "StateMachine+ProtocolManagerDelegate.h"
#import "DDLog.h"
const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation StateMachine (ProtocolManagerDelegate)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

-(BMErrorCode) OKToProcessControlPacketReceivedWithPacket:(ControlPacket*)packet
{       
    //DDLogInfo(@"\nOKToProcessControlPacketReceived");
    
    //is the statemachine in a position to accept a initial connection request from
    //a peer?
    ControlPacketType controlCodeType = [packet getControlCode];
    
    switch (controlCodeType) 
    {
        case CONTROL_PACKET_TYPE_INITIAL_HANDSHAKE_REQUEST:
        {
            //the netservice should be ready by now?        
            BMErrorCode error = [self runStateMachine:E_INITIAL_HANDSHAKE_REQ_RECEIVED_FROM_PEER 
                                             withData:packet];
            
            DDLogInfo(@"\nStateMachine: got peer name: %@", packet.mHostName);
           return error;
        }
            
        case CONTROL_PACKET_TYPE_INITIAL_HANDSHAKE_ACK:
        {
            if(packet.mControlAckErrorCode == BM_ERROR_NONE)
            {
                return [self runStateMachine:E_INITIAL_HANDSHAKE_ACK_SUCCESS_RECEIVED_FROM_PEER 
                                    withData:packet];
            }
            else 
            {
                return [self runStateMachine:E_INITIAL_HANDSHAKE_ACK_ERROR_RECEIVED_FROM_PEER 
                                    withData:nil];
            }
            break;
        }
            
        case CONTROL_PACKET_TYPE_START_MONITORING:
        {
            return [self runStateMachine:E_START_MONITORING_PACKET_RECEIVED_FROM_PEER 
                                withData:packet];
            break;
        }
            
        case CONTROL_PACKET_TYPE_START_MONITORING_ACK:
        {
            return [self runStateMachine:E_START_MONITORING_ACK_PACKET_RECEIVED_FROM_PEER 
                                withData:packet];
            break;
        }
            
        case CONTROL_PACKET_TYPE_STOP_MONITORING:
        {
            return [self runStateMachine:E_STOP_MONITORING_PACKET_RECEIVED_FROM_PEER 
                                withData:nil];
            break;
        }
            
        case CONTROL_PACKET_TYPE_STOP_MONITORING_ACK:
        {
            //TODO
            return BM_ERROR_NONE;
        }
            
        case CONTROL_PACKET_TYPE_TOGGLE_MODE:
        {
            return [self peerWantsToToggleMode];
        }
            
        case CONTROL_PACKET_TYPE_DISCONNECT_WITH_PEER:
        {
            return [self peerWantsToDisconnectWithUs];
        }
        
        case CONTROL_PACKET_TYPE_DISCONNECT_WITH_PEER_ACK:
        {
            return [self completeUserDisconnectWithPeerAfterACKWasReceived];
        }
            
        case CONTROL_PACKET_TYPE_PAUSE_ON_INTERRUPT:
        {
            return [self peerWantsToPauseOnInterrupt];
        }
            
        case CONTROL_PACKET_TYPE_RESUME_AFTER_INTERRUPT:
        {
            return [self peerWantsToResumeAfterInterrupt];
        }
            
        case CONTROL_PACKET_TYPE_RESUME_AFTER_INTERRUPT_ACK:
        {
            //TODO
            return BM_ERROR_NONE;
        }
            
        case CONTROL_PACKET_TYPE_TALK_TO_BABY_START:
        {
            return [self peerWantsToTalkToBabyAtPortNum:packet.mPortNum];
        }
            
        case CONTROL_PACKET_TYPE_TALK_TO_BABY_START_ACK:
        {
            return [self receivedTalkToBabyACKPacketFromPeer];
        }
            
        case CONTROL_PACKET_TYPE_TALK_TO_BABY_END:
        {
            return [self peerWantsToEndTalkingToBaby];
        }
            
        case CONTROL_PACKET_TYPE_PING_PEER_ACK:
        {
            return [self receivedPingAckFromPeer];
        }
            break;
            
        default:
            DDLogInfo(@"\nStateMachine: Error: Control Packet of unknown type received");
            break;
    }
    
    return BM_ERROR_NONE;
}

#pragma clang diagnostic pop
@end
