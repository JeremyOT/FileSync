//
//  FSAppDelegate.m
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 4/25/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import "FSAppDelegate.h"
#import "FileWatcher.h"
#import "SyncService.h"
#import "SyncConnection.h"
#import "SyncServiceBrowser.h"
#import "FSSynchronizer.h"

@interface FSAppDelegate ()

@property (nonatomic,retain) FileWatcher *watcher;
@property (nonatomic,retain) SyncService *service;
@property (nonatomic,retain) SyncServiceBrowser *browser;
@property (nonatomic,retain) NSMutableDictionary *remoteServices;
@property (nonatomic,retain) NSMutableArray *incomingSyncConnections;
@property (nonatomic,retain) NSMutableDictionary *outgoingSyncConnections;
@property (nonatomic,retain) NSString *renameSourcePath;

@end

@implementation FSAppDelegate

@synthesize window = _window;
@synthesize statusItem = _statusItem;
@synthesize statusMenu = _statusMenu;
@synthesize watcher = _watcher;
@synthesize service = _service;
@synthesize browser = _browser;
@synthesize remoteServices = _remoteServices;
@synthesize incomingSyncConnections = _incomingSyncConnections;
@synthesize outgoingSyncConnections = _outgoingSyncConnections;
@synthesize renameSourcePath = _renameSourcePath;

- (void)dealloc
{
    [_statusMenu release];
    [_statusItem release];
    [_watcher close];
    [_watcher release];
    [_service release];
    [_browser release];
    [_remoteServices release];
    [_incomingSyncConnections release];
    [_outgoingSyncConnections release];
    [_renameSourcePath release];
    [super dealloc];
}

-(void)updateMenu {
    [self.statusItem.menu removeAllItems];
    [self.statusItem.menu addItemWithTitle:[[NSHost currentHost] localizedName] action:NULL keyEquivalent:@""];
    [self.statusItem.menu addItem:[NSMenuItem separatorItem]];
    for (NSString *host in _remoteServices) {
        [self.statusItem.menu addItemWithTitle:host action:NULL keyEquivalent:@""];
    }
}

-(void)sycnDir:(NSString*)source withDir:(NSString*)sink forEvent:(FSEventStreamEventFlags)flags {
    [[NSFileManager defaultManager] createDirectoryAtPath:sink withIntermediateDirectories:YES attributes:[[NSFileManager defaultManager] attributesOfItemAtPath:source error:nil] error:nil];
    [[NSFileManager defaultManager] setAttributes:[[NSFileManager defaultManager] attributesOfItemAtPath:source error:nil] ofItemAtPath:sink error:nil];
}

-(void)syncFile:(NSString*)source withFile:(NSString*)sink forEvent:(FSEventStreamEventFlags)flags {
        FSSynchronizer *inSync = [[FSSynchronizer alloc] initWithFile:source];
        FSSynchronizer *outSync = [[FSSynchronizer alloc] initWithFile:sink];
        NSSet *diff = [outSync diffForSignature:inSync.hashSignature];
        NSArray *components = [inSync componentsForDiff:diff];
        [outSync updateFileWithComponents:components];
        [inSync release];
        [outSync release];
        NSData *idat = [NSData dataWithContentsOfFile:source];
    NSData *odat = [NSData dataWithContentsOfFile:sink];
    [[NSFileManager defaultManager] setAttributes:[[NSFileManager defaultManager] attributesOfItemAtPath:source error:nil] ofItemAtPath:sink error:nil];
    NSLog(@"%@ Sync Complete: %@\n", source, [idat isEqualToData:odat] ? @"Success" : @"Fail");
}

-(void)awakeFromNib {
    NSString *syncSource = @"/Users/jeremyot/Desktop/SyncTest";
    NSString *syncOut = @"/Users/jeremyot/Desktop/SyncOutput";

    FileWatcher *watcher = [[FileWatcher alloc] initWithBlock:^(NSString *file, FSEventStreamEventFlags flags, FSEventStreamEventId eventId) {
        if (flags & kFSEventStreamEventFlagItemRenamed) {
            if (_renameSourcePath) {
                [[NSFileManager defaultManager] moveItemAtPath:[_renameSourcePath stringByReplacingOccurrencesOfString:syncSource withString:syncOut] toPath:[file stringByReplacingOccurrencesOfString:syncSource withString:syncOut] error:nil];
                self.renameSourcePath = nil;
            } else {
                self.renameSourcePath = file;
            }
            return;
        }
        if (flags & kFSEventStreamEventFlagItemRemoved) {
            [[NSFileManager defaultManager] removeItemAtPath:[_renameSourcePath stringByReplacingOccurrencesOfString:syncSource withString:syncOut] error:nil];
            return;
        }
        if (flags & kFSEventStreamEventFlagItemIsFile) {
            [self syncFile:file withFile:[file stringByReplacingOccurrencesOfString:syncSource withString:syncOut] forEvent:flags];
        } else if (flags & kFSEventStreamEventFlagItemIsDir) {
            [self sycnDir:file withDir:[file stringByReplacingOccurrencesOfString:syncSource withString:syncOut] forEvent:flags];
        }
    }];
    watcher = [[FileWatcher alloc] init];
    [[NSFileManager defaultManager] createDirectoryAtPath:syncOut withIntermediateDirectories:YES attributes:nil error:nil];
    [watcher openEventStream:[NSArray arrayWithObject:syncSource] latency:1];
    return;
    self.remoteServices = [NSMutableDictionary dictionary];
    self.incomingSyncConnections = [NSMutableArray array];
    self.outgoingSyncConnections = [NSMutableDictionary dictionary];
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.title = @"FileSync";
    self.statusItem.menu = _statusMenu;
    self.statusItem.highlightMode = YES;
    _watcher = [[FileWatcher alloc] init];
    [_watcher openEventStream:[NSArray arrayWithObject:@"/Users/jeremyot/Desktop"] latency:1];
    _service = [[SyncService alloc] initWithName:[[NSHost currentHost] localizedName]];
    _browser = [[SyncServiceBrowser alloc] init];
    [_browser setServerAddedBlock:^(NSNetService *service) {
        if ([service.name isEqualToString:_service.netService.name]) {
            return NO;
        }
        [_remoteServices setObject:service forKey:service.name];
        SyncConnection *connection = [[[SyncConnection alloc] initWithNetService:service] autorelease];
        [connection setConnectionTerminatedBlock:^(SyncConnection *c) {
            DLog(@"Connection Terminated");
        }];
        [connection setMessageReceivedBlock:^(SyncConnection *c, NSDictionary *m) {
            DLog(@"Received Message: %@", m); 
            [c sendMessage:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Hi Back %@", service.name] forKey:@"message"]];
        }];
        if (![connection connect]) {
            DLog(@"Failed to connect");
        } else {
            [_outgoingSyncConnections setObject:connection forKey:service.name];
        }
        [connection setConnectionEstablishedBlock:^(SyncConnection *c) {
            [c sendMessage:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"I found you %@", service.name] forKey:@"message"]];
        }];
        return YES;
    }];
    [_browser setServerRemovedBlock:^(NSNetService *service) {
        [_remoteServices removeObjectForKey:service.name];
        DLog(@"Removed Server: %@", service);
    }];
    [_browser startWithBlock:^(SyncServiceBrowser *browser) {
        [self updateMenu];
    }];
    [_service setErrorBlock:^(SyncService *ss, NSNetService *ns, NSDictionary *info){
        DLog(@"Service Error: %@ %@ %@", ss, ns, info);
    }];
    [_service startWithAcceptBlock:^(SyncConnection *connection) {
        [connection setConnectionTerminatedBlock:^(SyncConnection *c) {
            [_incomingSyncConnections removeObject:c];
            DLog(@"Remote connection terminated");
        }];
        [connection setMessageReceivedBlock:^(SyncConnection *c, NSDictionary *m) {
            DLog(@"Received Remote Message: %@", m); 
        }];
        [connection sendMessage:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"You connected to %@", [[NSHost currentHost] localizedName]] forKey:@"Message"]];
        [_incomingSyncConnections addObject:connection];
    }];
}

@end
