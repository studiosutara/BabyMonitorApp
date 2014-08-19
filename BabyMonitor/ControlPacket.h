//
//  ControlPacket.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/11/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//
#import "BMUtility.h"

typedef enum ControlPacketType
{
    //initial handshake packets types
    CONTROL_PACKET_TYPE_INVALID,                           //0
    
    //Sent by device A to device B when A wants to connect with B
    CONTROL_PACKET_TYPE_INITIAL_HANDSHAKE_REQUEST,         //1
    
    //Sent by device B in response to the above message from device A
    CONTROL_PACKET_TYPE_INITIAL_HANDSHAKE_ACK,             //2
    
    //The transmitter gets to send this to the receiver, when the user chooses to 
    //start monitoring from the transmitter device
    CONTROL_PACKET_TYPE_START_MONITORING,                  //3
    
    //The receiver sends this to the receiver in response to the above message
    CONTROL_PACKET_TYPE_START_MONITORING_ACK,              //4
    
   //when user chooses to stop, this msg is sent to the peer to either stop
    //tx'ing or rx'ing for it's side. the Sender does the needful to stop 
    //from it's side
    CONTROL_PACKET_TYPE_STOP_MONITORING,                   //5
    
    //sent to peer in response to the above messgae
    CONTROL_PACKET_TYPE_STOP_MONITORING_ACK,               //6
    
    CONTROL_PACKET_TYPE_TOGGLE_MODE,                       //7
    
    CONTROL_PACKET_TYPE_TOGGLE_MODE_ACK,                   //8
    
    CONTROL_PACKET_TYPE_UNEXPECTED_PACKET_RECEIVED,        //9
    
    CONTROL_PACKET_TYPE_DISCONNECT_WITH_PEER,              //10
    
    CONTROL_PACKET_TYPE_DISCONNECT_WITH_PEER_ACK,          //11
    
    //No need for ACK here, we going to go ahead and PAUSE anyways
    CONTROL_PACKET_TYPE_PAUSE_ON_INTERRUPT,                //12
    
    //We will have to wait for the ACK here, there should be time for one
    CONTROL_PACKET_TYPE_RESUME_AFTER_INTERRUPT,            //13
    
    CONTROL_PACKET_TYPE_RESUME_AFTER_INTERRUPT_ACK,        //14
    
    CONTROL_PACKET_TYPE_TALK_TO_BABY_START,                //15
    
    CONTROL_PACKET_TYPE_TALK_TO_BABY_START_ACK,            //16
    
    CONTROL_PACKET_TYPE_TALK_TO_BABY_END,                  //17
    
    CONTROL_PACKET_TYPE_TALK_TO_BABY_END_ACK,              //18
    
    CONTROL_PACKET_TYPE_PING_PEER,                         //19
    
    CONTROL_PACKET_TYPE_PING_PEER_ACK,                     //20
    
    CONTROL_PACKET_TYPE_BATTERY_LEVEL_INFO,                //21
    
    CONTROL_PACKET_TYPE_MAX                                //22
} ControlPacketType;

#define CTRL_PACKET_SIZE 512

@interface ControlPacket : NSObject <NSCoding>
{
    ControlPacketType mControlPacketType;
    BMErrorCode       mControlAckErrorCode;
    NSString*         mHostName;
    NSString*         mHostService;
    MonitorMode       mPeerMonitorMode;
    uint16_t          mPortNum;
    uint             mBatteryLevel;
};

+(ControlPacket*) getNewControlPacketWithType:(ControlPacketType)type withError:(BMErrorCode) error; 
+(ControlPacket*) getNewStartMonPacketWithMode:(MonitorMode) mode andPortNum:(uint16_t) portNum;
+(ControlPacket*) getNewStartMonACKPacketWithPortNum:(uint16_t) portNum;
+(ControlPacket*) getNewHandshakePacketWithMode:(MonitorMode) mode;
+(ControlPacket*) getNewHandshakeACKPacketWithError:(BMErrorCode) error;
+(ControlPacket*) getNewStarTalkToBabyPacketWithMode:(MonitorMode) mode andPortNum:(uint16_t) portNum;
-(ControlPacketType) getControlCode;

+(ControlPacket*) getNewBatteryLevelPacketWithCurrentLevel;
-(void) printPacket;

@property (nonatomic) NSString* mHostName;
@property (nonatomic) NSString* mHostService;

@property (nonatomic)         BMErrorCode      mControlAckErrorCode;
@property                     MonitorMode      mPeerMonitorMode;
@property (nonatomic)         uint16_t         mPortNum;
@property (nonatomic)      uint mBatteryLevel;
@end