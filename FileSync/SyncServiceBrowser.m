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
@property (nonatomic,copy) void (^updatedServersBlock)(NSSet* servers);

@end

@implementation SyncServiceBrowser

@synthesize serviceBrowser = _serviceBrowser;
@synthesize servers = _servers;
@synthesize updatedServersBlock = _updatedServersBlock;

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
    [_updatedServersBlock release];
    [super dealloc];
}

#pragma mark - Networking

-(BOOL)startWithBlock:(void (^)(NSSet *servers))updatedServersBlock {
    if (_serviceBrowser) {
        [self stop];
    }
    _serviceBrowser = [[NSNetServiceBrowser alloc] init];
    if (!_serviceBrowser) {
        return NO;
    }
    self.updatedServersBlock = updatedServersBlock;
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
    if (moreComing) {
        return;
    }
    if (_updatedServersBlock) {
        _updatedServersBlock([NSSet setWithSet:_servers]);
    }
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    [_servers removeObject:aNetService];
    if (moreComing) {
        return;
    }
    if (_updatedServersBlock) {
        _updatedServersBlock([NSSet setWithSet:_servers]);
    }
}

@end
