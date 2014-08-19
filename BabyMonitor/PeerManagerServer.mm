/*
 File: TCPServer.m
 Abstract: A TCP server that listens on an arbitrary port.
 Version: 1.8
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2010 Apple Inc. All Rights Reserved.
 
 */

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <CFNetwork/CFSocketStream.h>
#import "Utilities.h"
#import "PeerManagerServer.h"
#include <netinet/tcp.h>
#import <ifaddrs.h>
#import <arpa/inet.h>

const int ddLogLevel = LOG_LEVEL_VERBOSE;


NSString * const TCPServerErrorDomain = @"TCPServerErrorDomain";

@interface PeerManagerServer ()
@property(nonatomic, strong) NSNetService* netService;
@property(assign) uint16_t port;
@property(nonatomic, assign) CFSocketNativeHandle nativeSocketHandle;
@end

@implementation PeerManagerServer

@synthesize delegate=_delegate, netService=_netService, port=_port, nativeSocketHandle = _nativeSocketHandle;

- (id)init 
{
  //  DDLogInfo(@"\nPeerManagerServer init...");
    self.nativeSocketHandle = 0;
    return self;
}

- (void)dealloc 
{
  //  DDLogInfo(@"\nPeerManagerServer: deallocing self");
    [self stop];
}

-(void)handleNewConnectionFromAddress:(NSInputStream *)inStream 
outputStream:(NSOutputStream *)outStream
{
   // DDLogInfo(@"\nPeerManagerServer: handleNewConnectionFromAddress");
    
    // if the delegate implements the delegate method, call it  
    if (self.delegate && [self.delegate 
                          respondsToSelector:@selector(didAcceptConnectionForServer:
                                                       inputStream:outputStream:)]) 
    { 
        [self.delegate didAcceptConnectionForServer:self 
                                 inputStream:inStream 
                                 outputStream:outStream];
    }
}

// This function is called by CFSocket when a new connection comes in.
// We gather some data here, and convert the function call to a method
// invocation on TCPServer.
static void TCPServerAcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) 
{
    PeerManagerServer *server = (__bridge PeerManagerServer *)info;

//    NSLog(@"\nPeerManagerServer: TCPServerAcceptCallBack server=%x, address=%x,  data=%x,  socket=%x",
//          (unsigned int)server, 
//          (unsigned int)address, 
//          (unsigned int)data, 
//          (unsigned int)socket); 
    
    if (kCFSocketAcceptCallBack == type) 
    { 
        if(server.delegate && [server.delegate respondsToSelector:@selector(isOkToAcceptNewConnection)] &&
            [server.delegate isOkToAcceptNewConnection])
        {
           
            // for an AcceptCallBack, the data parameter is a pointer to a CFSocketNativeHandle
            CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle *)data;
            
            CFReadStreamRef readStream = NULL;
            CFWriteStreamRef writeStream = NULL;
            CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocketHandle, &readStream, &writeStream);
            if (readStream && writeStream) 
            {
                if(!CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue))
                    NSLog(@"\nPeerManagerServer: error setting kCFStreamPropertyShouldCloseNativeSocket flag on readstream");
                
                if(!CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue))
                    NSLog(@"\nPeerManagerServer: error setting kCFStreamPropertyShouldCloseNativeSocket flag on writestream");
                
                if(!CFReadStreamSetProperty(readStream, kCFStreamPropertyNoCellular, kCFBooleanTrue))
                    NSLog(@"\nPeerManagerServer: error setting kCFStreamPropertyNoCellular flag on readstream");

                if(!CFWriteStreamSetProperty(writeStream, kCFStreamPropertyNoCellular, kCFBooleanTrue))
                    NSLog(@"\nPeerManagerServer: error setting kCFStreamPropertyNoCellular flag on writestream");
                
//                if(!CFReadStreamSetProperty(readStream, kCFStreamNetworkServiceType, kCFStreamNetworkServiceTypeBackground))
//                    NSLog(@"\nPeerManagerServer: error setting kCFStreamNetworkServiceTypeBackground flag on readstream");
//                
//                if(!CFWriteStreamSetProperty(writeStream, kCFStreamNetworkServiceType, kCFStreamNetworkServiceTypeBackground))
//                    NSLog(@"\nPeerManagerServer: error setting kCFStreamNetworkServiceTypeBackground flag on writestream");
                
                [server handleNewConnectionFromAddress:(__bridge NSInputStream *)readStream
                                          outputStream:(__bridge NSOutputStream *)writeStream];
            }
            else 
            {
                // on any failure, need to destroy the CFSocketNativeHandle 
                // since we are not going to use it any more
                close(nativeSocketHandle);
            }
            
            if (readStream) CFRelease(readStream);
            if (writeStream) CFRelease(writeStream);
        }
        else 
        {
        //    NSLog(@"\nPeerManagerServer:TCPServerAcceptCallBack, SM not ready to accept new connection");
            return;
        }
    }
}

- (BOOL)start:(NSError **)error 
{
    CFSocketContext socketCtxt = {0, (__bridge void*)self, NULL, NULL, NULL};	
    //();
	// Start by trying to do everything with IPv6.  This will work for both IPv4 and IPv6 clients 
    // via the miracle of mapped IPv4 addresses.	
    
    DDLogInfo(@"\nCFSocketCreate IPV6 CALLED");
    //|kCFSocketReadCallBack|kCFSocketDataCallBack|kCFSocketConnectCallBack|kCFSocketWriteCallBack,
    witap_socket = CFSocketCreate(kCFAllocatorDefault, 
                                  PF_INET6, 
                                  SOCK_STREAM, 
                                  IPPROTO_TCP, 
                                  kCFSocketAcceptCallBack,
                                  (CFSocketCallBack)&TCPServerAcceptCallBack, 
                                  &socketCtxt);
	
	if (witap_socket != NULL)	// the socket was created successfully
	{
		protocolFamily = PF_INET6;
	} 
    else // there was an error creating the IPv6 socket - could be running under iOS 3.x
	{
        DDLogInfo(@"\nCFSocketCreate IPV4 CALLED");
		
        witap_socket = CFSocketCreate(kCFAllocatorDefault, 
                                      PF_INET, 
                                      SOCK_STREAM, 
                                      IPPROTO_TCP, 
                                      kCFSocketAcceptCallBack, 
                                      (CFSocketCallBack)&TCPServerAcceptCallBack,
                                      &socketCtxt);
		if (witap_socket != NULL)
		{
			protocolFamily = PF_INET;
		}
	}
        
    if (NULL == witap_socket) 
    {
        if (error) *error = [[NSError alloc] initWithDomain:TCPServerErrorDomain 
                                                       code:kTCPServerNoSocketsAvailable 
                                                   userInfo:nil];
        if (witap_socket) CFRelease(witap_socket);
        witap_socket = NULL;
        return NO;
    }
	
	
    int yes = 1;
    setsockopt(CFSocketGetNative(witap_socket), SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));
    
    int flag = 1;
    int result = setsockopt(CFSocketGetNative(witap_socket),            /* socket affected */
                            IPPROTO_TCP,     /* set option at TCP level */
                            TCP_NODELAY,     /* name of option */
                            (char *) &flag,  /* the cast is historical
                                              cruft */
                            sizeof(int));    /* length of option value */
    if (result < 0)
    {
        DDLogInfo(@"\nTCPServer: unable to set the TCP_NODELAY socket option");
    }
	
	// set up the IP endpoint; use port 0, so the kernel will choose an arbitrary port for us, which will be advertised using Bonjour
	if (protocolFamily == PF_INET6)
	{
		struct sockaddr_in6 addr6;
		memset(&addr6, 0, sizeof(addr6));
		addr6.sin6_len = sizeof(addr6);
		addr6.sin6_family = AF_INET6;
		addr6.sin6_port = 0;
		addr6.sin6_flowinfo = 0;
		addr6.sin6_addr = in6addr_any;
		NSData *address6 = [NSData dataWithBytes:&addr6 length:sizeof(addr6)];
		
		if (kCFSocketSuccess != CFSocketSetAddress(witap_socket, (__bridge CFDataRef)address6)) 
        {
			if (error) *error = [[NSError alloc] initWithDomain:TCPServerErrorDomain 
                                                           code:kTCPServerCouldNotBindToIPv6Address 
                                                       userInfo:nil];
            
			if (witap_socket) CFRelease(witap_socket);
			witap_socket = NULL;
			return NO;
		}
		
		// now that the binding was successful, we get the port number 
		// -- we will need it for the NSNetService
		NSData *addr = (__bridge_transfer NSData *)CFSocketCopyAddress(witap_socket);
		memcpy(&addr6, [addr bytes], [addr length]);
		self.port = ntohs(addr6.sin6_port);
		
	} 
    else 
    {
		struct sockaddr_in addr4;
		memset(&addr4, 0, sizeof(addr4));
		addr4.sin_len = sizeof(addr4);
		addr4.sin_family = AF_INET;
		addr4.sin_port = 0;
		addr4.sin_addr.s_addr = htonl(INADDR_ANY);
		NSData *address4 = [NSData dataWithBytes:&addr4 length:sizeof(addr4)];
		
		if (kCFSocketSuccess != CFSocketSetAddress(witap_socket, (__bridge CFDataRef)address4)) 
        {
			if (error) *error = [[NSError alloc] initWithDomain:TCPServerErrorDomain 
                                                           code:kTCPServerCouldNotBindToIPv4Address 
                                                       userInfo:nil];
			if (witap_socket) CFRelease(witap_socket);
			witap_socket = NULL;
			return NO;
		}
		
		// now that the binding was successful, we get the port number 
		// -- we will need it for the NSNetService
		NSData *addr = (__bridge_transfer NSData *)CFSocketCopyAddress(witap_socket);
		memcpy(&addr4, [addr bytes], [addr length]);
		self.port = ntohs(addr4.sin_port);
	}
	
    // set up the run loop sources for the sockets
    CFRunLoopRef cfrl = CFRunLoopGetCurrent();
    CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, witap_socket, 0);
    CFRunLoopAddSource(cfrl, source, kCFRunLoopCommonModes);
    CFRelease(source);
	
    return YES;
}

- (BOOL)stop 
{
    [self disableBonjour];
    
   // DDLogInfo(@"PeerManagerServer: disabling bonjour");
	if (witap_socket) 
    {
		CFSocketInvalidate(witap_socket);
		CFRelease(witap_socket);
		witap_socket = NULL;
	}
	
	
    return YES;
}

- (BOOL) enableBonjourWithDomain:(NSString*)domain applicationProtocol:(NSString*)protocol name:(NSString*)name
{
    //();
	if(![domain length])
		domain = @""; //Will use default Bonjour registration doamins, typically just ".local"

	if(!protocol || ![protocol length] || witap_socket == NULL)
		return NO;
	
//    DDLogInfo(@"\nPeerManagerServer: Creating netservice with domain:%@, type:%@ name:%@, port %d", 
//          domain, 
//          protocol, 
//          [[UIDevice currentDevice] name],
//          self.port);
    
    //[[NSProcessInfo processInfo] hostName]
	self.netService = [[NSNetService alloc] initWithDomain:@"local" 
                                                      type:protocol 
                                                      name:[[UIDevice currentDevice] name]//[[NSProcessInfo processInfo] hostName]//
                                                      port:self.port];
	if(self.netService == nil)
		return NO;
	
	[self.netService scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[self.netService publish];
    DDLogInfo(@"\nPeerManagerServer: device name is %@", [[UIDevice currentDevice] name]);
    DDLogInfo(@"\nPeerManagerServer: published service: %@", [self.netService description]);
	[self.netService setDelegate:self];	
    
	return YES;
}

/*
 Bonjour will not allow conflicting service instance names (in the same domain), and may have automatically renamed
 the service if there was a conflict.  We pass the name back to the delegate so that the name can be displayed to
 the user.
 See http://developer.apple.com/networking/bonjour/faq.html for more information.
 */

- (void)netServiceDidPublish:(NSNetService *)sender
{
    //();
  //  DDLogInfo(@"\nPeerManagerServer: netServiceDidPublish");
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(serverDidEnableBonjour: withName:)])
    {
        /*if(sender == _netService)
            DDLogInfo(@"\n Both the services are the same!");
        else 
            DDLogInfo(@"\nBoth the services are not the same!");*/
        
		[self.delegate serverDidEnableBonjour:sender withName:[sender name]];
    }
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
  //  DDLogInfo(@"\nPeerManagerServer: netService: didNotPublish");
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(server:didNotEnableBonjour:)])
    {
		[self.delegate server:self didNotEnableBonjour:errorDict];
    }
}

- (void) disableBonjour
{
	if (self.netService) 
    {
	//	DDLogInfo(@"PeerManaherServer: disableBonjour");
		[self.netService stop];
		[self.netService removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
		self.netService = nil;
	}
}

- (NSString*) description
{
	return [NSString stringWithFormat:@"<%@ = 0x%08X | port %d | netService = %@>", [self class], (unsigned int)self, self.port, self.netService];
}

@end
