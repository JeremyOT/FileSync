//
//  SyncConnection.h
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 4/26/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SyncConnection : NSObject <NSNetServiceDelegate>

@property (nonatomic, retain, readonly) NSString *host;
@property (nonatomic, readonly) uint16_t port;
@property (nonatomic, readonly) BOOL readStreamOpen;
@property (nonatomic, readonly) BOOL writeStreamOpen;
@property (nonatomic, readonly) BOOL writing;
@property (nonatomic, readonly) BOOL reading;
@property (nonatomic, copy) void (^connectionTerminatedBlock)(SyncConnection*);
@property (nonatomic, copy) void (^messageReceivedBlock)(SyncConnection*, NSDictionary*);
@property (nonatomic, copy) void (^connectionEstablishedBlock)(SyncConnection*);
@property (nonatomic, copy) void (^stateChangedBlock)(SyncConnection*);

-(id)initWithHost:(NSString*)host port:(int)port;
-(id)initWithNativeSocketHandle:(CFSocketNativeHandle)nativeSocketHandle;
-(id)initWithNetService:(NSNetService*)service;
-(void)sendMessage:(NSDictionary*)message;
-(BOOL)connect;
-(void)close;

@end
