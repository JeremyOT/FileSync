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

NSString *FSSyncMessageTypeKey = @"Type";
NSString *FSSyncMessageDataKey = @"Data";
NSString *FSSyncMessagePathKey = @"Path";
NSString *FSSyncMessageSenderKey = @"Sender";

NSString *FSSyncMessageTypeFileList = @"FileList";
NSString *FSSyncMessageTypeHello = @"Hello";

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
//    [manager startSyncManager];
    [_syncManagers setObject:manager forKey:name];
}

-(void)removeMonitoredDirectory:(NSString*)name {
    [(FSSyncManager*)[_syncManagers objectForKey:name] stopSyncManager];
    [_syncManagers removeObjectForKey:name];
}

-(void)sendMessage:(NSString*)type data:(id)data path:(NSString*)path connection:(SyncConnection*)connection {
    [connection sendMessage:[NSDictionary dictionaryWithObjectsAndKeys:
                             _service.netService.name, FSSyncMessageSenderKey,
                             type, FSSyncMessageTypeKey,
                             data, FSSyncMessageDataKey,
                             path, FSSyncMessagePathKey,
                             nil]];
}

#pragma mark - Outgoing Sync

-(void)processMessage:(NSDictionary*)message forOutgoingConnection:(SyncConnection*)connection {
    
}

#pragma mark - Incoming Sync

-(void)processMessage:(NSDictionary*)message forIncomingConnection:(SyncConnection*)connection {
    // Process Hello
}

#pragma mark - Service Control

-(void)startSyncManagerWithBlock:(void (^)(NSArray *services))servicesUpdatedBlock {
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
            [self processMessage:m forOutgoingConnection:c];
        }];
        if (![connection connect]) {
            DLog(@"Failed to connect");
        } else {
            [_outgoingSyncConnections addObject:connection];
        }
        [connection setConnectionEstablishedBlock:^(SyncConnection *c) {
            [self sendMessage:FSSyncMessageTypeHello data:nil path:nil connection:c];
        }];
        return YES;
    }];
    [_browser setServerRemovedBlock:^(NSNetService *service) {
        [_remoteServices removeObjectForKey:service.name];
    }];
     [_browser startWithBlock:^(SyncServiceBrowser *browser) {
        servicesUpdatedBlock([[_remoteServices allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]);
    }];
    [_service setErrorBlock:^(SyncService *ss, NSNetService *ns, NSDictionary *info){
        DLog(@"Service Error: %@ %@ %@", ss, ns, info);
    }];
    [_service startWithAcceptBlock:^(SyncConnection *connection) {
        [connection setConnectionTerminatedBlock:^(SyncConnection *c) {
            [_incomingSyncConnections removeObject:c];
        }];
        [connection setMessageReceivedBlock:^(SyncConnection *c, NSDictionary *m) {
            [self processMessage:m forIncomingConnection:c];
        }];
        [_incomingSyncConnections addObject:connection];
    }];
}

@end
