//
//  BMUtility.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/18/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#define MAX_RECEIVABLE_MEDIA_DATA_SZ 44100


typedef enum
{
    INVALID_MODE,
    BABY_OR_TRANSMITTER_MODE,
    PARENT_OR_RECEIVER_MODE
}MonitorMode;

typedef enum
{
    NOT_CONNECTED,
    CONNECTING,
    CONNECTED_NOT_MONITORING,
    STARTING_MONITOR,
    MONITORING,
    RESTARTING,
    LISTENING_OR_TALKING, //TO PARENT/BABY
}BabyMonitorStatesForUI;

typedef enum
{
    BM_ERROR_MIN_INVALID = 1,                              //1
    BM_ERROR_NONE,                                         //2
    BM_ERROR_INVALID_INPUT_PARAM,                          //3
    BM_ERROR_OUT_OF_MEMORY,                                //4
    BM_ERROR_NETSERVICE_STREAM_FAIL,                       //5
    
    //SM ERRORS
    BM_ERROR_SM_NOT_INITIALIZED = 11,                       //11
    BM_ERROR_SM_STREAM_OPEN_PENDING,                        //12
    BM_ERROR_SM_UNEXPECTED_OR_UNWANTED_EVENT_RCVD,          //13
    BM_ERROR_SM_NOT_IN_EXPECTED_STATE,                      //14
    BM_ERROR_SM_NOT_CONNECTED_TO_PEER,                      //15
    BM_ERROR_SM_WRONG_MODE_CHANGE,                          //16
    BM_ERROR_SM_PEER_NOT_IN_EXPECTED_MODE,                  //17
    BM_ERROR_SM_NOT_IN_EXPECTED_MODE,                       //18
    
    
    //ProtocolManager Error
    BM_ERROR_PM_GET_SHARED_INSTANCE_FAIL = 31,              //31
    BM_ERROR_PM_NOT_INITIALIZED,                            //32
    
    //Protocol control message errors
    BM_ERROR_PM_INITIAL_HANDSHAKE_ERROR_NONE = 41,          //41
    BM_ERROR_PM_STOP_MONTORING_SUCCESS,                     //42
    BM_ERROR_PM_STOP_MONITORING_FAIL,                       //43
    BM_ERROR_PM_START_MONITORING_SUCCESS,                   //44
    BM_ERROR_PM_START_MONITORING_FAIL,                      //45
    
    //PS Error
    BM_ERROR_PS_GET_SHARED_INSTANCE_FAIL = 51,              //51
    BM_ERROR_PS_INVALID_PACKET_TYPE,                        //52
    BM_ERROR_PS_PACKET_SERIALIZATION_ERROR,                 //53
    
    //PR error
    BM_ERROR_PR_GET_SHARED_INSTANCE_FAIL = 61,              //61
    BM_ERROR_PR_WRONG_STATE,                                //62
    BM_ERROR_PR_DESERIALIZE_MEDIA_PACKET_FAILED,            //63
    
    //Audio Queue
    BM_AS_NETWORK_CONNECTION_FAILED = 71,                   //71
    BM_AS_FILE_STREAM_GET_PROPERTY_FAILED,                  //72
    BM_AS_FILE_STREAM_SEEK_FAILED,                          //73
    BM_AS_FILE_STREAM_PARSE_BYTES_FAILED,                   //74
    BM_AS_FILE_STREAM_OPEN_FAILED,                          //75
    BM_AS_FILE_STREAM_CLOSE_FAILED,                         //76
    BM_AS_AUDIO_DATA_NOT_FOUND,                             //77
    BM_AS_AUDIO_QUEUE_CREATION_FAILED,                      //78
    BM_AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED,             //79
    BM_AS_AUDIO_QUEUE_ENQUEUE_FAILED,                       //80
    BM_AS_AUDIO_QUEUE_ADD_LISTENER_FAILED,                  //81
    BM_AS_AUDIO_QUEUE_REMOVE_LISTENER_FAILED,               //82
    BM_AS_AUDIO_QUEUE_START_FAILED,                         //83
    BM_AS_AUDIO_QUEUE_PAUSE_FAILED,                         //84
    BM_AS_AUDIO_QUEUE_BUFFER_MISMATCH,                      //85
    BM_AS_AUDIO_QUEUE_DISPOSE_FAILED,                       //86       
    BM_AS_AUDIO_QUEUE_STOP_FAILED,                          //87
    BM_AS_AUDIO_QUEUE_FLUSH_FAILED,                         //88
    BM_AS_AUDIO_STREAMER_FAILED,                            //89
    BM_AS_GET_AUDIO_TIME_FAILED,                            //90
    BM_AS_AUDIO_BUFFER_TOO_SMALL,                           //91

    BM_ERROR_FAIL = 201,
    
    BM_ERROR_MAX =300
}BMErrorCode;

