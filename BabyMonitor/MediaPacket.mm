//
//  MediaPacket.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/11/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#include "MediaPacket.h"
#include "BMUtility.h"

MediaPacket::~MediaPacket()
{
    //NSLog(@"\nMedia packet freeing voicedata at %x", (uint)mVoiceData);
    free(mVoiceData);
}

void MediaPacket::debugPrint(char* buffer)
{
    /*MediaPacketToSendAndReceive packet;
    memcpy(&packet, buffer, sizeof(MediaPacketToSendAndReceive));
//    printf("\n/////");
    printf("\npackettype=%d, media packet type=%d, size in bytes = %lu", 
           packet.packetType, 
           packet.mediaPacketType, 
           packet.sizeInBytes);
    printf("\n////////////////////////////////////////////////////////////////////////////////////////////\n");*/
}

