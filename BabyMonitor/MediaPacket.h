//
//  MediaPacket.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/11/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

typedef enum
{
    MEDIA_PACKET_TYPE_INVALID,//0
    MEDIA_PACKET_TYPE_VOICE,  //1
    MEDIA_PACKET_TYPE_VIDEO   //2
}MediaPacketType; 

class MediaPacket 
{

private: 
          
public:
    
    //TODO: may need to figure out a way to move this to the private section
    //MEMBER VARS
    UInt32 msizeInBytes;
    MediaPacketType mMediaPacketType;
    void*  mVoiceData;
 
    
    MediaPacket()
    {
        msizeInBytes = 0;
        
        //TODO: will default to voice data for now
        mMediaPacketType = MEDIA_PACKET_TYPE_VOICE;
        mVoiceData = NULL;
    }
    
   ~MediaPacket();
    
    static void debugPrint(char* buffer);
};