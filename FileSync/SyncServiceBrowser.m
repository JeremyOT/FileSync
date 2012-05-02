//
//  SyncClient.m
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 4/29/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import "SyncServiceBrowser.h"

@interface SyncServiceBrowser ()

@property (nonatomic,retain) NSNetServiceBrowser *serviceBrowser;
@property (nonatomic,retain) NSMutableSet *servers;
@property (nonatomic,copy) void (^serversUpdatedBlock)(SyncServiceBrowser* browser);

@end

@implementation SyncServiceBrowser

@synthesize serviceBrowser = _serviceBrowser;
@synthesize servers = _servers;
@synthesize serversUpdatedBlock = _serversUpdatedBlock;
@synthesize serverAddedBlock = _serverAddedBlock;
@synthesize serverRemovedBlock = _serverRemovedBlock;

#pragma mark - Lifecycle

-(id)init {
    if ((self = [super init])) {
        _servers = [[NSMutableSet alloc] init];
    }
    return self;
}

-(void)dealloc {
    [_servers release];
    [_serviceBrowser release];
    [_serversUpdatedBlock release];
    [_serverAddedBlock release];
    [_serverRemovedBlock release];
    [super dealloc];
}

#pragma mark - Servers

-(NSSet *)allServers {
    return [NSSet setWithSet:_servers];
}

#pragma mark - Networking

-(BOOL)startWithBlock:(void (^)(SyncServiceBrowser *browser))serversUpdatedBlock {
    if (_serviceBrowser) {
        [self stop];
    }
    _serviceBrowser = [[NSNetServiceBrowser alloc] init];
    if (!_serviceBrowser) {
        return NO;
    }
    self.serversUpdatedBlock = serversUpdatedBlock;
    _serviceBrowser.delegate = self;
    [_serviceBrowser searchForServicesOfType:FSServiceType inDomain:FSSyncDomain];
    return YES;
}

-(void)stop {
    [_serviceBrowser stop];
    self.serviceBrowser = nil;
    [_servers removeAllObjects];
}

#pragma mark - NSNetServiceBrowser Delegate Methods

-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    [_servers addObject:aNetService];
    if (_serverAddedBlock) {
        if(!_serverAddedBlock(aNetService)) {
            [_servers removeObject:aNetService];
        }
    }
    if (moreComing) {
        return;
    }
    if (_serversUpdatedBlock) {
        _serversUpdatedBlock(self);
    }
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    if ([_servers containsObject:aNetService]) {
        [_servers removeObject:aNetService];
        if (_serverRemovedBlock) {
            _serverRemovedBlock(aNetService);
        }
    }
    if (moreComing) {
        return;
    }
    if (_serversUpdatedBlock) {
        _serversUpdatedBlock(self);
    }
}

@end
