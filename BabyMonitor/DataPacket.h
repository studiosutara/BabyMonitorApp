//
//  DataPacket.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 5/11/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//


//diff packet types
typedef enum
{
    PACKET_TYPE_INVALID=0x00,
    PACKET_TYPE_CONTROL=0x01,
    PACKET_TYPE_MEDIA=0x02
}DataPacketType;

class DataPacket 
{
protected:
    
public:
    //TODO may have to make this private later
    DataPacketType     mPacketType;

     DataPacketType getPacketType();
     DataPacket() {}
    ~DataPacket() {}
  
    void setPacketType(DataPacketType type) { mPacketType = type; }
    virtual char* serializePacket(unsigned int*)=0;
};

