//
//  SyncConnection.m
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 4/26/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import "SyncConnection.h"
#import "BSONSerialization.h"

@interface SyncConnection ()

@property (nonatomic, retain, readwrite) NSString *host;
@property (nonatomic, readwrite) uint16_t port;
@property (nonatomic, retain) NSNetService *netService;
@property (nonatomic) CFSocketNativeHandle connectedSocketHandle;
@property (nonatomic) CFReadStreamRef readStream;
@property (nonatomic, readwrite) BOOL readStreamOpen;
@property (nonatomic, retain) NSMutableData *readBuffer;
@property (nonatomic) CFWriteStreamRef writeStream;
@property (nonatomic, readwrite) BOOL writeStreamOpen;
@property (nonatomic, retain) NSMutableData *writeBuffer;
@property (nonatomic) int packetSize;

-(void)writeToStream;
-(void)readFromStream;

@end

@implementation SyncConnection

@synthesize host = _host;
@synthesize port = _port;
@synthesize netService = _netService;
@synthesize connectedSocketHandle = _connectedSocketHandle;
@synthesize readStream = _readStream;
@synthesize readStreamOpen = _readStreamOpen;
@synthesize readBuffer = _readBuffer;
@synthesize writeStream = _writeStream;
@synthesize writeStreamOpen = _writeStreamOpen;
@synthesize writeBuffer = _writeBuffer;
@synthesize packetSize = _packetSize;
@synthesize connectionTerminatedBlock = _connectionTerminatedBlock;
@synthesize messageReceivedBlock = _messageReceivedBlock;
@synthesize connectionEstablishedBlock = _connectionEstablishedBlock;

#pragma mark - Lifecycle

-(id)initWithHost:(NSString*)host port:(int)port {
    if ((self = [self init])) {
        self.host = host;
        self.port = port;
    }
    return self;
}

-(id)initWithNativeSocketHandle:(CFSocketNativeHandle)nativeSocketHandle {
    if ((self = [self init])) {
        self.connectedSocketHandle = nativeSocketHandle;
    }
    return self;
}

-(id)initWithNetService:(NSNetService *)service {
    if ((self = [self init])) {
        self.netService = service;
    }
    return self;
}

-(void)dealloc {
    [self close];
    [_host release];
    [_netService release];
    [_readBuffer release];
    [_writeBuffer release];
    [_connectionTerminatedBlock release];
    [_messageReceivedBlock release];
    [_connectionEstablishedBlock release];
    [super dealloc];
}

#pragma mark - Connection

-(BOOL)connect {
    if (_host) {
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (CFStringRef)_host, _port, &_readStream, &_writeStream);
        return [self setupSocketStreams];
    } else if (_connectedSocketHandle) {
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, _connectedSocketHandle, &_readStream, &_writeStream);
        return [self setupSocketStreams];
    } else if (_netService) {
        if (_netService.hostName) {
            self.host = _netService.hostName;
            self.port = _netService.port;
            CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (CFStringRef)_host, _port, &_readStream, &_writeStream);
            return [self setupSocketStreams];
        }
        _netService.delegate = self;
        [_netService resolveWithTimeout:5.0];
        return YES;
    }
    return NO;
}

-(BOOL)setupSocketStreams {
    if (!_readStream || !_writeStream) {
        [self close];
        return NO;
    }
    self.readBuffer = [[[NSMutableData alloc] init] autorelease];
    self.writeBuffer = [[[NSMutableData alloc] init] autorelease];
    CFReadStreamSetProperty(_readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
    CFWriteStreamSetProperty(_writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
    
    CFOptionFlags eventFlags = kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable |
    kCFStreamEventCanAcceptBytes | kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred;
    
    CFStreamClientContext context = {0, self, NULL, NULL, NULL};
    CFReadStreamSetClient(_readStream, eventFlags, readStreamEventHandler, &context);
    CFWriteStreamSetClient(_writeStream, eventFlags, writeStreamEventHandler, &context);
    
    CFReadStreamScheduleWithRunLoop(_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFWriteStreamScheduleWithRunLoop(_writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    
    if (!CFReadStreamOpen(_readStream) || !CFWriteStreamOpen(_writeStream)) {
        [self close];
        return NO;
    }
    return YES;
}

-(void)close {
    if (_readStream) {
        CFReadStreamUnscheduleFromRunLoop(_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        CFReadStreamClose(_readStream);
        CFRelease(_readStream);
        _readStream = NULL;
    }
    if (_writeStream) {
        CFWriteStreamUnscheduleFromRunLoop(_writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        CFWriteStreamClose(_writeStream);
        CFRelease(_writeStream);
        _writeStream = NULL;
    }
    self.readBuffer = nil;
    self.writeBuffer = nil;
    if (_netService) {
        [_netService stop];
        self.netService = nil;
    }
}

#pragma mark - Communication

-(void)sendMessage:(NSDictionary*)message {
    NSData *messageData = [NSKeyedArchiver archivedDataWithRootObject:message];
    NSInteger size = [messageData length];
    [_writeBuffer appendBytes:&size length:sizeof(size)];
    [_writeBuffer appendData:messageData];
    [self writeToStream];
}

void writeStreamEventHandler(CFWriteStreamRef stream, CFStreamEventType type, void *info) {
    SyncConnection *connection = (SyncConnection*)info;
    switch (type) {
        case kCFStreamEventOpenCompleted:
            connection->_writeStreamOpen = YES;
            if (connection->_readStreamOpen && connection->_connectionEstablishedBlock) {
                connection->_connectionEstablishedBlock(connection);
            }
            break;
        case kCFStreamEventCanAcceptBytes:
            [connection writeToStream];
            break;
        case kCFStreamEventEndEncountered:
        case kCFStreamEventErrorOccurred:
            [connection close];
            if (connection->_connectionTerminatedBlock) {
                connection->_connectionTerminatedBlock(connection);
            }
        default:
            break;
    }
}

-(void)writeToStream {
    if (!_writeStreamOpen || !_readStreamOpen || ![_writeBuffer length] || !CFWriteStreamCanAcceptBytes(_writeStream)) {
        return;
    }
    CFIndex writeLength = CFWriteStreamWrite(_writeStream, [_writeBuffer bytes], [_writeBuffer length]);
    if (writeLength == -1) {
        [self close];
        if (_connectionTerminatedBlock) {
            _connectionTerminatedBlock(self);
        }
        return;
    }
    [_writeBuffer replaceBytesInRange:(NSRange){0, writeLength} withBytes:NULL length:0];
}

void readStreamEventHandler(CFReadStreamRef stream, CFStreamEventType type, void *info) {
    SyncConnection *connection = (SyncConnection*)info;
    switch (type) {
        case kCFStreamEventOpenCompleted:
            connection->_readStreamOpen = YES;
            if (connection->_writeStreamOpen && connection->_connectionEstablishedBlock) {
                connection->_connectionEstablishedBlock(connection);
            }
            break;
        case kCFStreamEventHasBytesAvailable:
            [connection readFromStream];
            break;
        case kCFStreamEventEndEncountered:
        case kCFStreamEventErrorOccurred:
            [connection close];
            if (connection->_connectionTerminatedBlock) {
                connection->_connectionTerminatedBlock(connection);
            }
        default:
            break;
    }
}

-(void)readFromStream {
    UInt8 buffer[4096];
    while (CFReadStreamHasBytesAvailable(_readStream)) {
        CFIndex read = CFReadStreamRead(_readStream, buffer, sizeof(buffer));
        if (read <= 0) {
            [self close];
            if (_connectionTerminatedBlock) {
                _connectionTerminatedBlock(self);
            }
            return;
        }
        [_readBuffer appendBytes:buffer length:read];
    }
    while (YES) {
        NSInteger messageSize = 0;
        if ([_readBuffer length] < sizeof(NSInteger)) {
            return;
        }
        memcpy(&messageSize, [_readBuffer bytes], sizeof(NSInteger));
        if ([_readBuffer length] < sizeof(NSInteger) + messageSize) {
            return;
        }
        [_readBuffer replaceBytesInRange:(NSRange){0, sizeof(NSInteger)} withBytes:NULL length:0];
        NSDictionary *message = [NSKeyedUnarchiver unarchiveObjectWithData:[NSData dataWithBytes:[_readBuffer bytes] length:messageSize]]; 
        [_readBuffer replaceBytesInRange:(NSRange){0, messageSize} withBytes:NULL length:0];
        if (_messageReceivedBlock) {
            dispatch_async(dispatch_get_current_queue(), ^{
                _messageReceivedBlock(self, message);
            });
        }
    }
}

#pragma mark - NSNetService Delegate Methods

-(void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
    if (_connectionTerminatedBlock) {
        _connectionTerminatedBlock(self);
    }
    [self close];
}

-(void)netServiceDidResolveAddress:(NSNetService *)sender {
    self.host = sender.hostName;
    self.port = sender.port;
    self.netService = nil;
    if (![self connect]) {
        if (_connectionTerminatedBlock) {
            _connectionTerminatedBlock(self);
        }
        [self close];
    }
}

@end
