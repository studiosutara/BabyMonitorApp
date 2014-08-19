//
//  Utilities.h
//  BabyMonitor
//
//  Created by Shilpa Modi on 5/9/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>
#import "DDLog.h"
#import "BMUtility.h"

#define kBufferDurationSeconds .5

static CGFloat const iPhone5ScreenSize = 568;

static NSString* const kNotificationPacketSenderToPMOutControlStreamOpenComplete = @"OutControlStreamOpenComplete";

static NSString* const kNotificationPacketReceiverToPmInControlStreamOpenComplete = @"InControlStreamOpenComplete";

static NSString* const kNotificationPacketSenderToPMPacketSenderCreated = @"PacketSenderCreated";
static NSString* const kNotificationPacketReceiverToPMPacketReceiverCreated = @"PacketReceiverCreated";

static NSString* const kNotificationPacketReceiverToPMReceivedInitialHandshakeRequest=@"ReceivedInitialHandshakeRequest";

static NSString* const kNotificationPacketSenderToPMControlStreamHasSpaceAvailable = @"SenderControlStreamHasSpaceAvailable";

static NSString* const kNotificationPMToStateMachineStreamsOpen=@"BothStreamsOpen";

static NSString* const kNotificationPMToStateMachineControlStreamsOpen=@"ControlStreamsOpen";

static NSString* const kNotificationSMToBMVCSMStateChanged=@"SMStateChanged";
static NSString* const kNotificationSMToBMVCSMModeChanged=@"SMModeChanged";

static NSString* const kReachabilityChangedNotification=@"RechabilityChanged";
static NSString* const kReachabilityHaveNewHostName=@"HaveNewHostName";

static NSString* const kNotificationPMToSMControlStreamOpenFailed=@"ControlStreamOpenFailed";

static NSString* const kNotificationPMToSMControlStreamErrorOrEndOccured=@"ControlStreamErrorOrEndOccured";
static NSString* const kNotificationPMToMainViewPeerPausedOnCallInterrupt=@"PeerPausedOnCallInterrupt";
static NSString* const kNotificationPMToMainViewPeerBatteryLevelUpdate=@"PeerBatteryLevelUpdate";

static NSString* const kNotificationSMToUIStateChangeUpdate=@"StateChangeUpdateForUI";

#define ALog(fmt, ...) DDLogInfo((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

@interface Utilities : NSObject 
{
    
}


+ (void) showAlert:(NSString *)title;
+ (NSString*) getBonjourType;
+(UIImage*) getScreenShotWithSize:(CGSize) size andLayer:(CALayer*)layer;
+(void) playBeepSound;
+(void) print4char_errorcode:(int) code; //function to print the OSStaus error code value.
+(bool) isAudioInputAvailable;

+(BMErrorCode) activateAudioSession;
+(BMErrorCode) deactivateAudioSession;

+(CGFloat) getDeviceHeight;
+(CGFloat) getDeviceWidth;
@end
