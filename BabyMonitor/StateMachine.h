//
//  StateMachine.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 4/18/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PeerManager.h"
#import "Utilities.h"
#import "ProtocolManager.h"
#import "MediaRecorder.h"
#import "dispatch/dispatch.h"
#import "MediaPlayer.h"
#import "Reachability.h"

typedef enum 
{
    //we are going to req for a connection with another peer
    E_REQUEST_INITIAL_HANDSHAKE_WITH_PEER = 0,
    
    //we received a request from a peer for a fresh connection
    E_INITIAL_HANDSHAKE_REQ_RECEIVED_FROM_PEER,
    
    //we received an ack error for a connection req that we sent earlier
    E_INITIAL_HANDSHAKE_ACK_SUCCESS_RECEIVED_FROM_PEER,
    
    //we received an ack success for a connection req that we sent earlier
    E_INITIAL_HANDSHAKE_ACK_ERROR_RECEIVED_FROM_PEER,
    
    //we received a start monitoring packet from peer, 
    //need to do the needful depending on the mode we are in
    E_START_MONITORING_PACKET_RECEIVED_FROM_PEER,    
    
    //we received a start monitoring ACK from the peer
    //if we are in baby mode, then we go ahead and start sending recorded data
    //if we are in parent mode then we get ready to start receiiving data and playing it
    E_START_MONITORING_ACK_PACKET_RECEIVED_FROM_PEER,    
    
    //Peer wants us to stop monitoring/ it has stopped recording/playing on it's end
    E_STOP_MONITORING_PACKET_RECEIVED_FROM_PEER,

    //The peer received out "stop monitoring" req.
    //Depending on the mode, the peer successfully either stopped recording or playing
    E_STOP_MONITORING_ACK_PACKET_RECEIVED_FROM_PEER,

} StateMachineEvents;

typedef enum
{
    STATE_INITIALIZED = 0,
    STATE_CONTROL_STREAM_OPEN_PENDING,                                       //1
    STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ,          //2
    STATE_CONTROL_STREAM_OPEN_PENDING_BEFORE_SENDING_HANDSHAKE_REQ_ACK,      //3
    STATE_CONTROL_STREAM_OPEN_FAILED,                                        //4
    STATE_INITIALIZED_AND_CONTROL_STREAMS_OPENED,                            //5
    //this state also implies that the handshake req has been sent and
    //that the control streams are opened
    STATE_INITIAL_HANDSHAKE_REQ_RESPONSE_PENDING,                            //6
    STATE_CONNECTED_TO_PEER,                                                 //7

    STATE_CONTROL_STREAM_OPEN_PENDING_TO_SEND_START_MONITORING_PACKET,       //8    
    STATE_WAITING_FOR_START_MON_ACK_TO_START_MONITORING,                     //9   
    STATE_WAITING_TO_RECEIVE_MEDIA,                                          //10
    STATE_WAITING_FOR_MEDIA_RECORDER_TO_START_RECORDING,                     //11
    STATE_BABYMODE_RECORDING_AND_TRANSMITTING_MEDIA,                         //12
    STATE_PARENTMODE_RECEIVING_AND_PLAYING_MEDIA,                            //13
    
    STATE_STOPALL_AND_RESTART_MONITORING,                                    //14
    STATE_PEER_PAUSED_ON_INTERRUPT,                                          //15
    
    STATE_WAITING_FOR_NETSERVER_TO_PUBLISH_TO_RESUME_MONITORING,             //16
    STATE_WAITING_FOR_NETSERVER_TO_PUBLISH_TO_RESUME_CONNECTING,             //17

    //We have just sent the disconnect packet. we have to wait for the ACK
    //If we do not, then it may be too late to recv the ACK after th stream 
    //have been closed
    STATE_WAITING_FOR_DISCONNECT_ACK_TO_FINISH_DISCONNECTING,                //18
    
    
    //States for TTB when we are not actively monitoring
    STATE_BABYMODE_LISTENING_TO_PARENT,                                      //19
    STATE_PARENTMODE_WAITING_FOR_TALK_TO_BABY_START_ACK,                     //20
    STATE_PARENTMODE_TALKING_TO_BABY,                                        //21
    
    //States for TTB when we are actively monitoring
    
    STATE_WAITING_FOR_RESPONSE_FROM_PEER_TO_RESTART_OR_STOP_MONITORING,      //22
    STATE_LOST_WIFI_CONNECTION_WHILE_MONITORING,                             //23
    STATE_INVALID                                                            //24 
}StateMachineStates;


@class StateMachine;
@class PeerManager;

@protocol StateMachineDelegate <NSObject>
@optional
-(void) monitoringStatusChanged:(bool) isStarted;
-(void) talkingToBaby:(bool) isTalking;
-(BMErrorCode) SMStartAnimation;
-(BMErrorCode) SMStopAnimation;

-(void) inComingConnectionRequestFrom:(NSString*) peerName;
-(void) connectionStatusChanged:(bool) isConnected withPeer:(NSString*)peerName isIncoming:(bool) incoming;
@end

@interface StateMachine : NSObject<PeerManagerDelegate, ProtocolManagerDelegate, TCPServerDelegate, MediaPlayerDelegate, MediaRecorderDelegate>
{
    //will remember what the current mode of the statemachine
    MonitorMode            mCurrentBabyMonitorMode;
    StateMachineStates     mCurrentState;
    PeerManager*           mPeerManager;
    ProtocolManager*       mProtocolManager;
    MediaRecorder*         mMediaRecorder;
    MediaPlayer*           mMediaPlayer;
    
    NSString*              mOwnName;
    NSString*              mPeerServiceName;
    
    __weak id <StateMachineDelegate> mDelegate;
    
    //This bool is here to differentiate between whether we received the connection request 
    //or we initiated a resolve to request connection with the peer.
    //If true, then the other peer must have pinged us, so we will have to save the peer name when it comes in
    //through the handshake request control packet.
    bool                   mReceivedTCPHandleRequest;
    
    //Alert: "Do you also want to toggle the peer's mode"
    UIAlertView*           mTogglePeerModeAlert;
    //Alert: "Changing mode to ---"
    UIAlertView*           mToggleModeAlert;
    
    BMErrorCode            mACKErrorCode;
    
    NSTimer*               mHandshakeReqResponseTimer;
    NSTimer*               mStartMonitorReqResponseTimer;
    NSTimer*               mPingPeerResponseTimer;
    NSTimer*               mTransientStateTimer;
    
    NSMutableArray*        mReadableStateTable;
    
    bool                   mTTBWhileMonitoring;
    
    uint                   mNumOfConnectionRetries;
}

////////////////////////Implemented in StateMachine.m/////////////////////
-(void) showLostConnectionAlertWithSound;
- (void) start;
- (BMErrorCode) runStateMachine:(StateMachineEvents)event withData:(id) data;
- (bool) isCurrentlyRecording;
- (bool) isCurrentlyPlaying;

- (void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary *)change
                      context:(void *)context;

- (void) playerStateChangedTo:(AudioStreamerState) newState;
- (void) recorderStateChangedTo:(AudioRecorderState) newState;

- (BMErrorCode) changedBabyMonitorModeTo:(MonitorMode) mode;

-(void) didAcceptConnectionForServer:(PeerManagerServer*)server
                                 inputStream:(NSInputStream*)readStream
                                outputStream:(NSOutputStream*)writeStream;

////////////////////////Implemented in StateMachine.m/////////////////////
-(BMErrorCode) OKToProcessControlPacketReceivedWithPacket:(ControlPacket*)packet;

//the peer manager calls this delegate function when the user selects a peer and resolve is complete
- (BMErrorCode) isOKToProcessHandshakeRequestFromPeer:(ControlPacket*) packet;
- (BMErrorCode) isOKToProcessHandshakeACKReceivedFromPeerWithError:(bool) withError;

- (BMErrorCode) userWantsToStopMonitoring:(bool)andSendStopPacket;
- (BMErrorCode) userWantsToStartMonitoring;

-(void) startStartMonitorReqResponseTimer;
-(void) startMonitorReqResponseTimerFired;
-(void) stopStartMonitorReqResponseTimer;

- (bool) isReadyToStartRecordingAndSending;
- (bool) isReadyToStartReceivingAndPlaying;
- (bool) isListeningToParent;
- (bool) isTalkingToBaby;

- (BMErrorCode) requestInitialHandshakeAfterResolve:(NSNetService*) netService;
- (BMErrorCode) initiateInitialHandShakeWithPeer:(NSNetService*) data;
-(void) startHandshakeReqResponseTimer;
-(void) handshakeReqResponseTimerFired;
-(void) stopHandShakeReqResponseTimer;

- (void) setupMediaPlayerWithPortNumber:(uint16_t) portnum;
- (BMErrorCode) receivedStartMonitoringPacketFromPeerWithPortNum:(uint16_t) portnum;
-(BMErrorCode) receivedStartMonitoringACKPacketFromPeerWithError:(BMErrorCode) errorCode
                                                      andPortNum:(uint16_t) portNum;
- (BMErrorCode) checkControlStreamBeforeRecordingInBabyMode;
- (BMErrorCode) SetupAndSendStartMONPacket;


-(BMErrorCode)  receivedPauseMonitoringPacketFromPeer;
- (BMErrorCode) receivedStopMonitoringPacketFromPeer;
- (BMErrorCode) receivedStopMonitoringACKPacketFromPeer;

- (void) serverDidEnableBonjour:(NSNetService*)service withName:(NSString *)string;
- (void) didAcceptConnectionForServer:(PeerManagerServer*)server 
                         inputStream:(NSInputStream*)readStream 
                        outputStream:(NSOutputStream*)writeStream;
- (bool) isOkToAcceptNewConnection;

- (void) server:(PeerManagerServer*)server didNotEnableBonjour:(NSDictionary *)errorDict;

-(void) setupMediaRecorderWithPortNum:(uint16_t) portnum;

//All the operations here will be on the backend
- (BMErrorCode) userWantsToDisconnectWithPeer;
- (BMErrorCode) completeUserDisconnectWithPeerAfterACKWasReceived;
- (BMErrorCode) peerWantsToDisconnectWithUs;
-(void) disconnectComplete;

/////////////////////Change Mode related functions////////////////
- (BMErrorCode) peerWantsToToggleMode;
- (BMErrorCode) userToggledMode;

- (void) printAppState;
- (BMErrorCode) handleAppCameToForeground;
- (BMErrorCode) handleAppWillComeToForeground;
- (BMErrorCode) reconnectWithSavedPeer;
- (void) completeResumeMonitor;
-(BMErrorCode) restartMonitoringAfterInterrupt;

- (BMErrorCode) peerWantsToPauseOnInterrupt;

- (BMErrorCode) handleAppWillGoToBackground:(bool) isCallActive;

- (BMErrorCode) peerWantsToResumeAfterInterrupt;

- (BMErrorCode) peerCameOnline:(NSNetService*) netService;
- (BMErrorCode) peerWentOffline:(NSNetService*) netService;
- (void) receiveMediaPacketTimeoutMaxed;
- (void) sendMediaPacketTimeoutMaxed;

-(void) writeToPersistentStrorage;
-(void) writeStateToPersistentStrorage;
-(void) writeModeToPersistentStrorage;
-(void) writePeerNameToPersistentStrorage;

-(void) readFromPersistentStorage;
+(bool) isATransientState:(StateMachineStates) state;
+(bool) isAConnectedState:(StateMachineStates) state;

-(BMErrorCode) userWantsToTalkToBaby;
-(BMErrorCode) peerWantsToTalkToBabyAtPortNum:(uint16_t) portNum;
-(BMErrorCode) receivedTalkToBabyACKPacketFromPeer;
-(BMErrorCode) peerWantsToEndTalkingToBaby;

-(void) pingPeerAndWaitForResponse;
-(BMErrorCode) receivedPingAckFromPeer;
-(void) startPingPeerResponseTimer;
-(void) stopPingPeerResponseTimer;
-(void) pingPeerResponseTimerFired;

-(void) reachabilityChanged:(NetworkStatus) status;

-(BMErrorCode) StopMediaPlayer;
-(BMErrorCode) StopMediaRecorder;

-(BMErrorCode) userWantsToMuteVolume;

@property             MonitorMode            mCurrentBabyMonitorMode;
@property             StateMachineStates     mCurrentState;
@property (nonatomic) PeerManager*           mPeerManager;
@property (nonatomic) ProtocolManager*       mProtocolManager; 

@property (nonatomic) bool                   mReceivedTCPHandleRequest;

@property (nonatomic, weak) id <StateMachineDelegate> mDelegate;                 

@property (nonatomic) NSString*              mOwnName;
@property (nonatomic) UIAlertView*           mTogglePeerModeAlert;
@property (nonatomic) UIAlertView*           mToggleModeAlert;

@property (nonatomic) MediaPlayer*           mMediaPlayer;
@property (nonatomic) MediaRecorder*         mMediaRecorder;

@property             BMErrorCode            mACKErrorCode;
@property (nonatomic) NSMutableArray*        mReadableStateTable;
@end

