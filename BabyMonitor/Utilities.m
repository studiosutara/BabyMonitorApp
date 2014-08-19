//
//  Utilities.m
//  BabyMonitor
//
//  Created by Shilpa Modi on 5/9/11.
//  Copyright 2011 Studio Sutara LLC. All rights reserved.
//

#import "Utilities.h"

const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation Utilities

+ (void) showAlert:(NSString *)title
{
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Warning" 
                                                        message:title 
                                                       delegate:self 
                                              cancelButtonTitle:@"OK" 
                                              otherButtonTitles:nil];
	[alertView show];
}

+ (NSString*) getBonjourType 
{
    //DDLogInfo(@"\nbonjourTypeFromIdentifier: %@", [NSString stringWithFormat:@"_%@._tcp.", identifier]);
    
    return [NSString stringWithFormat:@"_%@._tcp.", @"HearMeMommy"];
}

+(UIImage*) getScreenShotWithSize:(CGSize) size andLayer:(CALayer*)layer
{
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
        UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    else
        UIGraphicsBeginImageContext(size);
    
    [layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

+(BMErrorCode) activateAudioSession
{
    DDLogInfo(@"\nUTILTITIES: ACTIVATE SESSION");
    OSStatus oserror = AudioSessionSetActive(true);
    
    if(oserror)
    {
        //DDLogInfo(@"\nUtilities: audioSessionSetActive error");
        [Utilities print4char_errorcode:oserror];
        
        return BM_ERROR_FAIL;
    }

    DDLogInfo(@"\nUtilities: AudioSession Activated");
    return BM_ERROR_NONE;
}

+(BMErrorCode) deactivateAudioSession
{
    DDLogInfo(@"\nUTILTITIES: DEACTIVATE SESSION");
    OSStatus oserror = AudioSessionSetActive(false);
    
    if(oserror)
    {
        //DDLogInfo(@"\nUtilities: deactivateAudioSession error");
        [Utilities print4char_errorcode:oserror];
        
        //return BM_ERROR_FAIL;
    }
    
    DDLogInfo(@"\nUtilities: AudioSession Deactivated");
    return BM_ERROR_NONE;
}

+(void) print4char_errorcode:(int) code //function to print the OSStaus error code value.
{
    DDLogInfo(@"\nUtilties: print4char_errorcode: %d", code);
    int c1 = (code >> 24) & 0xFF;
    int c2 = (code >> 16) & 0xFF; 
    int c3 = (code >> 8) & 0xFF;
    int c4 = code & 0xFF; 
    
    DDLogInfo(@"code = %c%c%c%c", c1, c2, c3, c4);
}
/*+ (void) printNetService:(NSNetService*) netService
{
    DDLogInfo(@"\n===================================NETSERVICE PRINT START=====================================");
    NSData* address = [[netService addresses] objectAtIndex:0];
    struct sockaddr_in* socketAddress = (struct sockaddr_in *)[address bytes];
    NSString* ipString = [NSString stringWithFormat: @"%s", inet_ntoa (socketAddress->sin_addr)];
    int port = socketAddress->sin_port;
    DDLogInfo(@"\nServer found is %@ port is: %d",ipString,port);
    
    DDLogInfo(@"\nservice name %@" ,[netService name]);
    DDLogInfo(@"\n==============================================================================================");
    
}*/


+(bool) isAudioInputAvailable
{
    UInt32 inputAvailable = 0;
    UInt32 size = sizeof(inputAvailable);
    
    OSStatus error = AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable, &size, &inputAvailable);
    if (error) 
    {
        DDLogInfo(@"ERROR GETTING INPUT AVAILABILITY! %ld\n", error);
    }
    
    return inputAvailable;
}

+(void) playBeepSound
{
  //  NSLog(@"\nUtilities: PlayBeepSound");
    SystemSoundID soundID;
    NSString *pewPewPath = [[NSBundle mainBundle] 
                            pathForResource:@"System_Notify" ofType:@"caf"];
    NSURL *pewPewURL = [NSURL fileURLWithPath:pewPewPath];
        
    OSStatus error = AudioServicesCreateSystemSoundID((__bridge CFURLRef)pewPewURL, &soundID);
    if(error)
    {
        DDLogInfo(@"\nUtilities, error creating system sound");
        [Utilities print4char_errorcode:error];
    }
    
    AudioServicesPlaySystemSound(soundID);
    
    AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);

}

+(CGFloat) getDeviceHeight
{
    return [[UIScreen mainScreen] bounds].size.height;
}

+(CGFloat) getDeviceWidth
{
    return [[UIScreen mainScreen] bounds].size.width;
}

@end
