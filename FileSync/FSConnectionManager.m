//
//  FSConnectionManager.m
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/7/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import "FSConnectionManager.h"
#import "SyncService.h"
#import "SyncConnection.h"
#import "SyncServiceBrowser.h"
#import "FSSyncManager.h"

@interface FSConnectionManager ()

@property (nonatomic,retain) NSMutableDictionary *remoteServices;
@property (nonatomic,retain) NSMutableSet *incomingSyncConnections;
@property (nonatomic,retain) NSMutableSet *outgoingSyncConnections;
@property (nonatomic,retain) SyncService *service;
@property (nonatomic,retain) SyncServiceBrowser *browser;
@property (nonatomic,retain) NSMutableDictionary *syncManagers;

@end

@implementation FSConnectionManager

@synthesize remoteServices = _remoteServices;
@synthesize incomingSyncConnections = _incomingSyncConnections;
@synthesize outgoingSyncConnections = _outgoingSyncConnections;
@synthesize service = _service;
@synthesize browser = _browser;
@synthesize syncManagers = _syncManagers;

#pragma mark - Lifecycle

-(id)init {
    if ((self = [super init])) {
        _service = [[SyncService alloc] initWithName:[[NSHost currentHost] localizedName]];
        _browser = [[SyncServiceBrowser alloc] init];
        _outgoingSyncConnections = [NSMutableSet set];
        _incomingSyncConnections = [NSMutableSet set];
        _syncManagers = [NSMutableDictionary dictionary];
    }
    return self;
}

-(void)dealloc {
    [_service release];
    [_browser release];
    [_outgoingSyncConnections release];
    [_incomingSyncConnections release];
    [_syncManagers release];
    [super dealloc];
}

#pragma mark - Sync Managers

-(void)addMonitoredDirectory:(NSString*)name atPath:(NSString*)path {
    FSSyncManager *manager = [[[FSSyncManager alloc] initWithName:name path:path] autorelease];
    [manager startSyncManager];
    [_syncManagers setObject:manager forKey:name];
}

-(void)removeMonitoredDirectory:(NSString*)name {
    [(FSSyncManager*)[_syncManagers objectForKey:name] stopSyncManager];
    [_syncManagers removeObjectForKey:name];
}

#pragma mark - Outgoing Sync

-(void)continueSyncForOutgoingConnection:(SyncConnection*)connection message:(NSDictionary*)message {
    
}

#pragma mark - Incoming Sync

-(void)continueSyncForIncomingConnection:(SyncConnection*)connection message:(NSDictionary*)message {
    
}

#pragma mark - Service Control

-(void)startSyncManager {
    [_browser setServerAddedBlock:^(NSNetService *service) {
        if ([service.name isEqualToString:_service.netService.name]) {
            return NO;
        }
        [_remoteServices setObject:service forKey:service.name];
        SyncConnection *connection = [[[SyncConnection alloc] initWithNetService:service] autorelease];
        [connection setConnectionTerminatedBlock:^(SyncConnection *c) {
            [_outgoingSyncConnections removeObject:c];
        }];
        [connection setMessageReceivedBlock:^(SyncConnection *c, NSDictionary *m) {
            [self continueSyncForOutgoingConnection:c message:m];
        }];
        if (![connection connect]) {
            DLog(@"Failed to connect");
        } else {
            [_outgoingSyncConnections addObject:connection];
        }
        [connection setConnectionEstablishedBlock:^(SyncConnection *c) {
            [c sendMessage:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"I found you %@", service.name] forKey:@"message"]];
        }];
        return YES;
    }];
    [_browser setServerRemovedBlock:^(NSNetService *service) {
        [_remoteServices removeObjectForKey:service.name];
    }];
    [_browser startWithBlock:^(SyncServiceBrowser *browser) {
//        [self updateMenu];
    }];
    [_service setErrorBlock:^(SyncService *ss, NSNetService *ns, NSDictionary *info){
        DLog(@"Service Error: %@ %@ %@", ss, ns, info);
    }];
    [_service startWithAcceptBlock:^(SyncConnection *connection) {
        [connection setConnectionTerminatedBlock:^(SyncConnection *c) {
            [_incomingSyncConnections removeObject:c];
        }];
        [connection setMessageReceivedBlock:^(SyncConnection *c, NSDictionary *m) {
            [self continueSyncForIncomingConnection:c message:m];
        }];
        [_incomingSyncConnections addObject:connection];
    }];
}

@end
