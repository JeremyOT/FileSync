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

@interface FSAppDelegate ()

@property (nonatomic,retain) FileWatcher *watcher;
@property (nonatomic,retain) SyncService *service;
@property (nonatomic,retain) SyncServiceBrowser *browser;

@end

@implementation FSAppDelegate

@synthesize window = _window;
@synthesize statusItem = _statusItem;
@synthesize statusMenu = _statusMenu;
@synthesize watcher = _watcher;
@synthesize service = _service;
@synthesize browser = _browser;

- (void)dealloc
{
    [_statusMenu release];
    [_statusItem release];
    [_watcher close];
    [_watcher release];
    [_service release];
    [_browser release];
    [super dealloc];
}

-(void)awakeFromNib {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.title = @"FileSync";
    self.statusItem.menu = _statusMenu;
    self.statusItem.highlightMode = YES;
    [self.statusItem.menu addItemWithTitle:[[NSHost currentHost] localizedName] action:NULL keyEquivalent:@""];
    [self.statusItem.menu addItem:[NSMenuItem separatorItem]];
    _watcher = [[FileWatcher alloc] init];
    [_watcher openEventStream:[NSArray arrayWithObject:@"/Users/jeremyot/Desktop"] latency:1];
    _service = [[SyncService alloc] initWithName:[[NSHost currentHost] localizedName]];
    _browser = [[SyncServiceBrowser alloc] init];
    [_browser startWithBlock:^(NSSet *servers) {
        DLog(@"Services Updated");
        for (NSNetService *service in servers) {
            DLog(@"Service: %@ @%@", service, service.hostName);
            SyncConnection *connection = [[SyncConnection alloc] initWithNetService:service];
            [connection setConnectionTerminatedBlock:^(SyncConnection *c) {
                DLog(@"Connection Terminated");
            }];
            [connection setMessageReceivedBlock:^(SyncConnection *c, NSDictionary *m) {
                DLog(@"Received Message: %@", m); 
            }];
            if (![connection connect]) {
                DLog(@"Failed to connect");
            }
        }
    }];
    [_service setErrorBlock:^(SyncService *ss, NSNetService *ns, NSDictionary *info){
        DLog(@"Service Error: %@ %@ %@", ss, ns, info);
    }];
    [_service startWithAcceptBlock:^(SyncConnection *connection) {
        [connection setConnectionTerminatedBlock:^(SyncConnection *c) {
            DLog(@"Remote connection terminated");
        }];
        [connection setMessageReceivedBlock:^(SyncConnection *c, NSDictionary *m) {
            DLog(@"Received Remote Message: %@", m); 
            [c sendMessage:[NSDictionary dictionaryWithObject:@"Hi Back" forKey:@"message"]];
        }];
        DLog(@"Connection from %@:%d", connection.host, connection.port);
        [connection sendMessage:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Message, hello from %@", [[NSHost currentHost] localizedName]] forKey:@"Message"]];
    }];
}

@end
