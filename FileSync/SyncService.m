//
//  SyncService.m
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 4/26/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//
#include <sys/socket.h>
#include <netinet/in.h>

#import "SyncService.h"
#import "SyncConnection.h"

@interface SyncService ()

@property (nonatomic, retain, readwrite) NSNetService *netService;
@property (nonatomic, copy) NSString *serviceName;
@property (nonatomic, assign, readwrite) uint16_t port;
@property (nonatomic, assign) CFSocketRef listenSocket;

-(BOOL)createSocket;
-(void)closeSocket;
-(BOOL)publishService;
-(void)unpublishService;

@end

@implementation SyncService

@synthesize netService = _netService;
@synthesize serviceName = _serviceName;
@synthesize port = _port;
@synthesize listenSocket = _listenSocket;
@synthesize acceptBlock = _acceptBlock;
@synthesize errorBlock = _errorBlock;


#pragma mark - Lifecycle

-(id)initWithName:(NSString*)name {
    if ((self = [self init])) {
        self.serviceName = name;
    }
    return self;
}

-(void)dealloc {
    [_netService release];
    [_serviceName release];
    [_acceptBlock release];
    [_errorBlock release];
    [super dealloc];
}

#pragma mark - Service

-(BOOL)startWithAcceptBlock:(void (^)(SyncConnection *connection))acceptBlock {
    if (![self createSocket]) {
        return NO;
    }
    if (![self publishService]) {
        [self closeSocket];
        return NO;
    }
    self.acceptBlock = acceptBlock;
    return YES;
}

-(void)stop {
    self.acceptBlock = nil;
    self.errorBlock = nil;
    [self closeSocket];
    [self unpublishService];
}

#pragma mark - Callbacks

static void serverAcceptHandler(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    SyncService *service = (SyncService*)info;
    if (type != kCFSocketAcceptCallBack) {
        return;
    }
    CFSocketNativeHandle nativeHandle = *(CFSocketNativeHandle*)data;
    SyncConnection *connection = [[[SyncConnection alloc] initWithNativeSocketHandle:nativeHandle] autorelease];
    if (!connection) {
        close(nativeHandle);
        return;
    }
    if (![connection connect]) {
        [connection close];
        return;
    }
    if (service->_acceptBlock) {
        service->_acceptBlock(connection);
    }
}

#pragma mark - Networking


-(BOOL)createSocket {
    CFSocketContext context = {0, self, NULL, NULL, NULL};
    if (!(_listenSocket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP,
                                         kCFSocketAcceptCallBack, (CFSocketCallBack)&serverAcceptHandler,&context))) {
        return NO;
    }
    
    // Make sure address is reused for each connection
    int existingSocket = 1;
    setsockopt(CFSocketGetNative(_listenSocket), SOL_SOCKET, SO_REUSEADDR,
               &existingSocket, sizeof(existingSocket));
    
    // Bind socket to endpoint, address assigned by kernel
    struct sockaddr_in socketAddress;
    memset(&socketAddress, 0, sizeof(socketAddress));
    socketAddress.sin_len = sizeof(socketAddress);
    socketAddress.sin_family = AF_INET;
    socketAddress.sin_port = 0;
    socketAddress.sin_addr.s_addr = htonl(INADDR_ANY);
    
    NSData *socketAddressData = [NSData dataWithBytes:&socketAddress length:sizeof(socketAddress)];
    
    if (CFSocketSetAddress(_listenSocket, (CFDataRef)socketAddressData) != kCFSocketSuccess) {
        CFRelease(_listenSocket);
        _listenSocket = NULL;
        return NO;
    }
    
    // Get address assigned to socket
    NSData *assignedSocketAddressData = [(NSData*)CFSocketCopyAddress(_listenSocket) autorelease];
    struct sockaddr_in assignedSocketAddress;
    memcpy(&assignedSocketAddress, [assignedSocketAddressData bytes], [assignedSocketAddressData length]);
    self.port = ntohs(assignedSocketAddress.sin_port);
    
    // Connect socket to run loop
    CFRunLoopRef currentRunLoop = CFRunLoopGetCurrent();
    CFRunLoopSourceRef runLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _listenSocket, 0);
    CFRunLoopAddSource(currentRunLoop, runLoopSource, kCFRunLoopCommonModes);
    CFRelease(runLoopSource);
    
    return YES;
}

-(void)closeSocket {
    if (_listenSocket) {
        CFSocketInvalidate(_listenSocket);
        CFRelease(_listenSocket);
        _listenSocket = NULL;
    }
}

#pragma mark - Bonjour

-(BOOL)publishService {
    if (!(_netService = [[NSNetService alloc] initWithDomain:FSSyncDomain type:FSServiceType name:_serviceName port:_port])) {
        return NO;
    }
    [_netService scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    _netService.delegate = self;
    [_netService publish];
    return YES;
}

-(void)unpublishService {
    if (_netService) {
        [_netService stop];
        [_netService removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        _netService = nil;
    }
}

#pragma mark - NSNetService Delegate Methods

-(void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict {
    if (sender != _netService) {
        return;
    }
    if (_errorBlock) {
        _errorBlock(self, sender, errorDict);
    }
    [self stop];
}

@end
