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
@property (nonatomic,retain) NSMutableDictionary *syncListenerConnections;
@property (nonatomic,retain) SyncService *service;
@property (nonatomic,retain) SyncServiceBrowser *browser;
@property (nonatomic,retain) NSMutableDictionary *syncManagers;
@property (nonatomic,retain) NSMutableDictionary *syncDates;

-(void)sendMessage:(NSString*)type data:(id)data path:(NSString*)path connection:(SyncConnection*)connection;

@end

@implementation FSConnectionManager

NSString *FSSyncMessageTypeKey = @"Type";
NSString *FSSyncMessageDataKey = @"Data";
NSString *FSSyncMessagePathKey = @"Path";
NSString *FSSyncMessageSenderKey = @"Sender";

NSString *FSSyncMessageTypeHello = @"Hello";
NSString *FSSyncMessageTypeMonitoredPathList = @"PathList";
NSString *FSSyncMessageTypeModificationDates = @"ModificationDates";
NSString *FSSyncMessageTypeRequestSync = @"RequestSync";
NSString *FSSyncMessageTypeFile = @"File";
NSString *FSSyncMessageTypeComponent = @"Component";
NSString *FSSyncMessageTypeDiff = @"Diff";
NSString *FSSyncMessageTypeRemovedPath = @"RemovedPath";

@synthesize remoteServices = _remoteServices;
@synthesize incomingSyncConnections = _incomingSyncConnections;
@synthesize outgoingSyncConnections = _outgoingSyncConnections;
@synthesize syncListenerConnections = _syncListenerConnections;
@synthesize service = _service;
@synthesize browser = _browser;
@synthesize syncManagers = _syncManagers;
@synthesize syncDates = _syncDates;
@synthesize syncStateChangedBlock = _syncStateChangedBlock;

#pragma mark - Lifecycle

-(id)init {
    if ((self = [super init])) {
        _service = [[SyncService alloc] initWithName:[[NSHost currentHost] localizedName]];
        _browser = [[SyncServiceBrowser alloc] init];
        _outgoingSyncConnections = [[NSMutableSet alloc] init];
        _incomingSyncConnections = [[NSMutableSet alloc] init];
        _syncListenerConnections = [[NSMutableDictionary alloc] init];
        _syncManagers = [[NSMutableDictionary alloc] init];
        _syncDates = [[NSMutableDictionary alloc] init];
        _remoteServices = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(void)dealloc {
    [_service release];
    [_browser release];
    [_outgoingSyncConnections release];
    [_incomingSyncConnections release];
    [_syncListenerConnections release];
    [_syncManagers release];
    [_remoteServices release];
    [_syncStateChangedBlock release];
    [super dealloc];
}

#pragma mark - Sync State

-(void)activityNotification {
    if (_syncStateChangedBlock) {
        for (FSSyncManager *manager in [_syncManagers allValues]) {
            if (manager.activeSynchronizerCount) {
                _syncStateChangedBlock(YES);
                return;
            }
        }
        _syncStateChangedBlock(NO);
    }
}

#pragma mark - Sync Managers

-(NSArray*)monitoredDirectories {
    return [_syncManagers allKeys];
}

-(void)addMonitoredDirectory:(NSString*)name atPath:(NSString*)path {
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    FSSyncManager *manager = [[[FSSyncManager alloc] initWithName:name path:path] autorelease];
    [manager setSyncStatusChangedBlock:^{
        [self activityNotification];
    }];
    [_syncListenerConnections setObject:[NSMutableSet set] forKey:name];
    [manager startSyncManagerWithBlock:^(NSArray *syncEvents) {
        for (SyncConnection *connection in [_syncListenerConnections objectForKey:name]) {
            [self sendMessage:FSSyncMessageTypeFile data:syncEvents path:name connection:connection];
        }
    }];
    [_syncManagers setObject:manager forKey:name];
    for (SyncConnection *incomingConnection in _incomingSyncConnections) {
        [self sendMessage:FSSyncMessageTypeMonitoredPathList data:[NSArray arrayWithObject:name] path:nil connection:incomingConnection];
    }
}

-(void)removeMonitoredDirectory:(NSString*)name {
    [(FSSyncManager*)[_syncManagers objectForKey:name] stopSyncManager];
    [_syncManagers removeObjectForKey:name];
    for (SyncConnection *outgoingConnection in _outgoingSyncConnections) {
        [self sendMessage:FSSyncMessageTypeRemovedPath data:name path:name connection:outgoingConnection];
    }
    [_syncListenerConnections removeObjectForKey:name];
}

#pragma mark - Sync Listeners

-(void)addSyncListenerConnection:(SyncConnection*)connection forPath:(NSString*)path {
    [[_syncListenerConnections objectForKey:path] addObject:connection];
}

-(void)removeSyncListenerConnection:(SyncConnection*)connection forPath:(NSString*)path {
    [[_syncListenerConnections objectForKey:path] removeObject:connection];
}

-(void)removeSyncListenerConnection:(SyncConnection*)connection {
    for (NSString *path in _syncListenerConnections) {
        [self removeSyncListenerConnection:connection forPath:path];
    }
}

#pragma mark - Messaging

-(void)sendMessage:(NSString*)type data:(id)data path:(NSString*)path connection:(SyncConnection*)connection {
    DLog(@"Sending %@: %@", type, path);
    [connection sendMessage:[NSDictionary dictionaryWithObjectsAndKeys:
                             _service.netService.name, FSSyncMessageSenderKey,
                             type, FSSyncMessageTypeKey,
                             data, FSSyncMessageDataKey,
                             path, FSSyncMessagePathKey,
                             nil]];
}

-(void)processMessage:(NSDictionary*)message forOutgoingConnection:(SyncConnection*)connection {
    NSString *type = [message objectForKey:FSSyncMessageTypeKey];
    NSString *path = [message objectForKey:FSSyncMessagePathKey];
    id data = [message objectForKey:FSSyncMessageDataKey];
    DLog(@"Outgoing Connection %@ Message for %@", type, path);
    if ([type isEqualToString:FSSyncMessageTypeMonitoredPathList]) {
        for (NSString *name in data) {
            if ([_syncManagers objectForKey:name]) {
                [self sendMessage:FSSyncMessageTypeModificationDates data:[[_syncManagers objectForKey:name] modificationDates] path:name connection:connection];
            }
        }
    } else if ([type isEqualToString:FSSyncMessageTypeRequestSync]) {
        [[_syncManagers objectForKey:path] forceSyncForPaths:data block:^(NSArray *syncEvents) {
            [self sendMessage:FSSyncMessageTypeFile data:syncEvents path:path connection:connection];
        }];
        [self addSyncListenerConnection:connection forPath:path];
    } else if ([type isEqualToString:FSSyncMessageTypeComponent]) {
        [self sendMessage:FSSyncMessageTypeDiff data:[[_syncManagers objectForKey:path] diffForComponentData:data] path:path connection:connection];
    } else if ([type isEqualToString:FSSyncMessageTypeRemovedPath]) {
        [self removeSyncListenerConnection:connection forPath:path];
    }
}

-(void)processMessage:(NSDictionary*)message forIncomingConnection:(SyncConnection*)connection {
    NSString *sender = [message objectForKey:FSSyncMessageSenderKey];
    NSString *type = [message objectForKey:FSSyncMessageTypeKey];
    NSString *path = [message objectForKey:FSSyncMessagePathKey];
    id data = [message objectForKey:FSSyncMessageDataKey];
    DLog(@"Incoming Connection %@ Message for %@", type, path);
    if ([type isEqualToString:FSSyncMessageTypeHello]) {
        if (![_syncDates objectForKey:sender]) {
            [_syncDates setObject:[NSMutableDictionary dictionary] forKey:sender];
        }
        [self sendMessage:FSSyncMessageTypeMonitoredPathList data:[_syncManagers allKeys] path:nil connection:connection];
    } else if ([type isEqualToString:FSSyncMessageTypeModificationDates]) {
        [self sendMessage:FSSyncMessageTypeRequestSync data:[[_syncManagers objectForKey:path] requestedPathsForModificationDates:data sinceTime:[[_syncDates objectForKey:sender] objectForKey:path]] path:path connection:connection];
    } else if ([type isEqualToString:FSSyncMessageTypeFile]) {
        DLog(@"Files: %@", path);
        [[_syncManagers objectForKey:path] syncEvents:data componentSyncBlock:^(NSDictionary *componentData) {
            DLog(@"Component Data");
            [self sendMessage:FSSyncMessageTypeComponent data:componentData path:path connection:connection];
        }];
    } else if ([type isEqualToString:FSSyncMessageTypeDiff]) {
        DLog(@"Complete: %@", path);
        [[_syncManagers objectForKey:path] completeFileSyncWithDiffData:data];
        [[_syncDates objectForKey:sender] setObject:[NSDate date] forKey:path];
    }
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
            [self removeSyncListenerConnection:c];
            DLog(@"Connection Terminated");
        }];
        [connection setMessageReceivedBlock:^(SyncConnection *c, NSDictionary *m) {
            [self activityNotification];
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
            DLog(@"Connection Terminated");
        }];
        [connection setMessageReceivedBlock:^(SyncConnection *c, NSDictionary *m) {
            [self activityNotification];
            [self processMessage:m forIncomingConnection:c];
        }];
        [_incomingSyncConnections addObject:connection];
    }];
}

-(void)stopSyncManager {
    [_browser stop];
    [_service stop];
    for (SyncConnection *connection in _incomingSyncConnections) {
        [connection close];
    }
    for (SyncConnection *connection in _outgoingSyncConnections) {
        [connection close];
    }
}

@end
