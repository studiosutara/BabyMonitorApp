//
//  ControlPacket.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/11/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#include "ControlPacket.h"
#include <stdio.h>
#include <iostream>
#import "DDLog.h"
#import "PersistentStorage.h"

const int ddLogLevel = LOG_LEVEL_VERBOSE;

#define MAX_CONTROL_PACKET_LENGTH 128
@implementation ControlPacket

@synthesize mHostName;
@synthesize mControlAckErrorCode;
@synthesize mPeerMonitorMode;
@synthesize mPortNum;
@synthesize mHostService;
@synthesize mBatteryLevel;

- (void) encodeWithCoder:(NSCoder*)encoder 
{
    [encoder encodeInt:mControlPacketType forKey:@"ControlPacketType"];
    [encoder encodeInt:mControlAckErrorCode forKey:@"AckErrorCode"];
    [encoder encodeObject:mHostName forKey:@"HostName"];
    [encoder encodeObject:mHostService forKey:@"HostService"];
    [encoder encodeInt:mPeerMonitorMode forKey:@"MonitorMode"];
    [encoder encodeInt32:mPortNum forKey:@"PortNum"];
    [encoder encodeInt:[[UIDevice currentDevice] batteryLevel]*100 forKey:@"BatteryLevel"];
 //   [encoder encodeInt:9 forKey:@"BatteryLevel"];
}

- (id) initWithCoder:(NSCoder*)decoder 
{
   if(!decoder)
   {
       DDLogInfo(@"\nControlPacket: inable to decode. Decoder is nil");
       return nil;
   }

    //self = [super initWithCoder:decoder];

    @try 
    {
        
      //  DDLogInfo(@"\n---------------------ControlPacket BEGIN-------------------");
        // NOTE: Decoded objects are auto-released and must be retained
        mControlPacketType   = (ControlPacketType)[decoder decodeIntForKey:@"ControlPacketType"];
        //DDLogInfo(@"\nControlPacket: PACKET TYPE:   %d", mControlPacketType);
        
        mControlAckErrorCode = (BMErrorCode)[decoder decodeIntForKey:@"AckErrorCode"];
        //DDLogInfo(@"\nControlPacket: ERROR CODE:    %d", mControlAckErrorCode);
        
        mHostName = [decoder decodeObjectForKey:@"HostName"];
//        if(mHostName)
//            DDLogInfo(@"\nControlPacket: HOST NAME:     %@", mHostName);
        
        mHostService = [decoder decodeObjectForKey:@"HostService"];
//        if(mHostService)
//            DDLogInfo(@"ControlPacket Host Service: %@", mHostService);
        
        mPeerMonitorMode = (MonitorMode)[decoder decodeIntForKey:@"MonitorMode"];
        //DDLogInfo(@"\nControlPacket: MONITOR MODE:  %d", mPeerMonitorMode);

        mPortNum = (uint16_t) [decoder decodeInt32ForKey:@"PortNum"];
        //DDLogInfo(@"\nControlPacket: PORT NUM:      %d", mPortNum);
        
        mBatteryLevel = (uint) [decoder decodeIntForKey:@"BatteryLevel"];
//        DDLogInfo(@"\nControlPacket: Battery Level: %u", mBatteryLevel);
//        
//        DDLogInfo(@"\n---------------------ControlPacket END-------------------");

    }
    @catch (NSException *exception) {
        DDLogInfo(@"main: Caught %@: %@", [exception name], [exception reason]);
    }

    return self;
}

+(ControlPacket*) getNewControlPacketWithType:(ControlPacketType)type withError:(BMErrorCode) error
{
    ControlPacket* newControlPacket = [[ControlPacket alloc] init];
    
    if(!newControlPacket)
    {
        return NULL;
    }
       
    newControlPacket->mControlPacketType = type;
    
    newControlPacket->mControlAckErrorCode =   error;
    
    newControlPacket->mHostName = nil;
    newControlPacket->mHostService = nil;
    
    newControlPacket->mPortNum = 0;
    
    return newControlPacket;
}

+(ControlPacket*) getNewHandshakePacketWithMode:(MonitorMode) mode
{
    ControlPacket* newControlPacket = [[ControlPacket alloc] init];
    
    if(!newControlPacket)
    {
        return NULL;
    }
    
    newControlPacket->mHostName =    [NSString stringWithFormat:@"%@", [[UIDevice currentDevice] name]];
    newControlPacket->mHostService = [NSString stringWithFormat:@"%@", [[NSProcessInfo processInfo] hostName]];
    newControlPacket->mControlPacketType = CONTROL_PACKET_TYPE_INITIAL_HANDSHAKE_REQUEST;
    
    newControlPacket->mControlAckErrorCode =  BM_ERROR_NONE;
    newControlPacket->mPeerMonitorMode = mode;
    
    return newControlPacket;
}

+(ControlPacket*) getNewHandshakeACKPacketWithError:(BMErrorCode) error
{
    ControlPacket* newControlPacket = [[ControlPacket alloc] init];
    
    if(!newControlPacket)
    {
        return NULL;
    }
    
    newControlPacket->mHostName = [NSString stringWithFormat:@"%@", [[UIDevice currentDevice] name]];
    newControlPacket->mHostService = [NSString stringWithFormat:@"%@", [[NSProcessInfo processInfo] hostName]];
    
    newControlPacket->mControlPacketType = CONTROL_PACKET_TYPE_INITIAL_HANDSHAKE_ACK;
    newControlPacket->mControlAckErrorCode =  error;
    
    return newControlPacket;
}

+(ControlPacket*) getNewStartMonPacketWithMode:(MonitorMode) mode andPortNum:(uint16_t) portNum
{
    ControlPacket* newControlPacket = [[ControlPacket alloc] init];
    
    if(!newControlPacket)
    {
        return NULL;
    }
    
    newControlPacket->mHostName = [NSString stringWithFormat:@"%@", [[UIDevice currentDevice] name]];
    newControlPacket->mHostService = [NSString stringWithFormat:@"%@", [[NSProcessInfo processInfo] hostName]];
    
    newControlPacket->mControlPacketType = CONTROL_PACKET_TYPE_START_MONITORING;
    
    newControlPacket->mControlAckErrorCode =  BM_ERROR_NONE;
    
    newControlPacket->mPeerMonitorMode = mode;
    newControlPacket->mPortNum = portNum;
    
    return newControlPacket;
}

+(ControlPacket*) getNewStartMonACKPacketWithPortNum:(uint16_t) portNum
{
    ControlPacket* newControlPacket = [[ControlPacket alloc] init];
    
    if(!newControlPacket)
    {
        return NULL;
    }
    
    newControlPacket->mHostName = [NSString stringWithFormat:@"%@", [[UIDevice currentDevice] name]];
    newControlPacket->mHostService = [NSString stringWithFormat:@"%@", [[NSProcessInfo processInfo] hostName]];
    
    newControlPacket->mControlPacketType = CONTROL_PACKET_TYPE_START_MONITORING_ACK;
    
    newControlPacket->mControlAckErrorCode =  BM_ERROR_NONE;
    
    newControlPacket->mPeerMonitorMode = [PersistentStorage readSMModeFromPersistentStorage];
    newControlPacket->mPortNum = portNum;
    
    return newControlPacket;
}

+(ControlPacket*) getNewStarTalkToBabyPacketWithMode:(MonitorMode) mode andPortNum:(uint16_t) portNum
{
    ControlPacket* newControlPacket = [[ControlPacket alloc] init];
    
    if(!newControlPacket)
    {
        return NULL;
    }
    
    newControlPacket->mHostName = [NSString stringWithFormat:@"%@", [[UIDevice currentDevice] name]];
    newControlPacket->mHostService = [NSString stringWithFormat:@"%@", [[NSProcessInfo processInfo] hostName]];
    
    newControlPacket->mControlPacketType = CONTROL_PACKET_TYPE_TALK_TO_BABY_START;
    
    newControlPacket->mControlAckErrorCode =  BM_ERROR_NONE;
    
    newControlPacket->mPeerMonitorMode = mode;
    newControlPacket->mPortNum = portNum;
    
    return newControlPacket;
}

+(ControlPacket*) getNewBatteryLevelPacketWithCurrentLevel
{
    ControlPacket* newControlPacket = [[ControlPacket alloc] init];
    
    if(!newControlPacket)
    {
        return NULL;
    }
    
    newControlPacket->mControlPacketType = CONTROL_PACKET_TYPE_BATTERY_LEVEL_INFO;

    newControlPacket->mBatteryLevel = [[UIDevice currentDevice] batteryLevel]*100;
    DDLogInfo(@"\nControlPacket: BatteryLevel = %d", newControlPacket->mBatteryLevel);
    return newControlPacket;
}

-(ControlPacketType) getControlCode
{
    return mControlPacketType;
}

-(void) printPacket
{
    
}

@end
