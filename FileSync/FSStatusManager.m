//
//  FSStatusManager.m
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/13/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import "FSStatusManager.h"
#import "FSConnectionManager.h"

typedef enum {
    FSMenuItemServerSeparator = 1,
    FSMenuItemServer = 2,
    FSMenuItemPathSeparator = 3,
    FSMenuItemPath = 4,
} FSMenuItem;

@interface FSStatusManager ()

@property (nonatomic, retain) NSURL *storageURL;
@property (nonatomic, retain) NSURL *syncDirectoryStorageURL;
@property (nonatomic, retain) NSArray *serverNames;
@property (nonatomic, retain) FSConnectionManager *connectionManager;
@property (nonatomic, retain) NSStatusItem *statusItem;
@property (nonatomic, retain) NSMutableDictionary *syncPaths;
@property (nonatomic, retain) NSMenuItem *toggleMenuItem;
@property (nonatomic, retain) NSMutableDictionary *serverMenuItems;
@property (nonatomic, retain) NSMutableDictionary *pathMenuItems;

-(void)createMenu;
-(void)updateMenu;

@end

@implementation FSStatusManager

@synthesize storageURL = _storageURL;
@synthesize syncDirectoryStorageURL = _syncDirectoryStorageURL;
@synthesize serverNames = _serverNames;
@synthesize connectionManager = _connectionManager;
@synthesize enabled = _enabled;
@synthesize syncPaths = _syncPaths;
@synthesize statusItem = _statusItem;
@synthesize toggleMenuItem = _toggleMenuItem;
@synthesize serverMenuItems = _serverMenuItems;
@synthesize pathMenuItems = _pathMenuItems;

#pragma mark - Lifecycle

-(id)init {
    if ((self = [super init])) {
        self.storageURL = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] objectAtIndex:0];
        self.syncDirectoryStorageURL = [_storageURL URLByAppendingPathComponent:@"syncPaths.plist"];
        [[NSFileManager defaultManager] createDirectoryAtURL:_syncDirectoryStorageURL withIntermediateDirectories:YES attributes:nil error:nil];
        self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:60];
        _statusItem.title = @"FileSync";
        _statusItem.menu = [[[NSMenu alloc] initWithTitle:@"FileSync"] autorelease];
        _statusItem.menu.delegate = self;
        _connectionManager = [[FSConnectionManager alloc] init];
        [_connectionManager setSyncStateChangedBlock:^(BOOL syncing) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                _statusItem.title = syncing ? @"Syncing" : @"FileSync";
            });
        }];
        _serverMenuItems = [[NSMutableDictionary alloc] init];
        _pathMenuItems = [[NSMutableDictionary alloc] init];
        [self createMenu];
    }
    return self;
}

-(void)dealloc {
    [_storageURL release];
    [_syncDirectoryStorageURL release];
    [_serverNames release];
    [_connectionManager release];
    [_syncPaths release];
    [_toggleMenuItem release];
    [[NSStatusBar systemStatusBar] removeStatusItem:_statusItem];
    [_statusItem release];
    [_serverMenuItems release];
    [_pathMenuItems release];
    [super dealloc];
}

#pragma mark - Syncing

-(void)startSyncing {
    [_connectionManager startSyncManagerWithBlock:^(NSArray *services) {
        self.serverNames = [services sortedArrayUsingSelector:@selector(localizedDescription)];
        [self updateMenu];
    }];
    _enabled = YES;
    self.toggleMenuItem.title = @"Pause";
    self.toggleMenuItem.action = @selector(stopSyncing);
}

-(void)stopSyncing {
    [_connectionManager stopSyncManager];
    _enabled = NO;
    self.toggleMenuItem.title = @"Resume";
    self.toggleMenuItem.action = @selector(startSyncing);
}

#pragma mark - Menu Operations

-(void)quit {
    [[NSApplication sharedApplication] terminate:self];
}

#pragma mark - Status Item

-(void)createMenu {
    NSMenu *menu = self.statusItem.menu;
    [menu removeAllItems];
    [menu addItemWithTitle:[[NSHost currentHost] localizedName] action:NULL keyEquivalent:@""];
    if (_enabled) {
        self.toggleMenuItem = [menu addItemWithTitle:@"Pause" action: @selector(stopSyncing) keyEquivalent:@""];
    } else {
        self.toggleMenuItem = [menu addItemWithTitle:@"Resume" action: @selector(startSyncing) keyEquivalent:@""];
    }
    _toggleMenuItem.target = self;
    NSMenuItem *serverSeparator = [NSMenuItem separatorItem];
    serverSeparator.tag = FSMenuItemServerSeparator;
    [menu addItem:serverSeparator];
    NSMenuItem *pathSeparator = [NSMenuItem separatorItem];
    pathSeparator.tag = FSMenuItemPathSeparator;
    [menu addItem:pathSeparator];
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *prefsItem = [menu addItemWithTitle:@"Preferences" action:NULL keyEquivalent:@""];
    prefsItem.target = self;
    NSMenuItem *helpItem = [menu addItemWithTitle:@"Help" action:NULL keyEquivalent:@""];
    helpItem.target = self;
    NSMenuItem *quitItem = [menu addItemWithTitle:@"Quit" action:@selector(quit) keyEquivalent:@""];
    quitItem.target = self;
    [self updateMenu];
}

-(void)updateMenu {
    NSMenu *menu = self.statusItem.menu;
    NSInteger serverIndex = [menu indexOfItemWithTag:FSMenuItemServerSeparator] + 1;
    while ([menu itemAtIndex:serverIndex].tag == FSMenuItemServer) {
        [menu removeItemAtIndex:serverIndex];
    }
    for (NSString *server in _serverNames) {
        NSMenuItem *item = [menu insertItemWithTitle:server action:NULL keyEquivalent:@"" atIndex:serverIndex++];
        [item setEnabled:NO];
        item.tag = FSMenuItemServer;
    }
    if (![_serverNames count]) {
        NSMenuItem *item = [menu insertItemWithTitle:@"No connections" action:NULL keyEquivalent:@"" atIndex:serverIndex++];
        [item setEnabled:NO];
        item.tag = FSMenuItemServer;
    }
    NSInteger pathIndex = [menu indexOfItemWithTag:FSMenuItemPathSeparator] + 1;
    while ([menu itemAtIndex:pathIndex].tag == FSMenuItemPath) {
        [menu removeItemAtIndex:pathIndex];
    }
    for (NSString *path in [[self.syncPaths allKeys] sortedArrayUsingSelector:@selector(localizedDescription)]) {
        NSMenuItem *item = [menu insertItemWithTitle:[NSString stringWithFormat:@"%@ (%@)", path, [_syncPaths objectForKey:path]]  action:NULL keyEquivalent:@"" atIndex:pathIndex++];
        [item setEnabled:NO];
        item.tag = FSMenuItemPath;
    }
    if (![_syncPaths count]) {
        NSMenuItem *item = [menu insertItemWithTitle:@"No paths synced" action:NULL keyEquivalent:@"" atIndex:pathIndex++];
        [item setEnabled:YES];
        item.tag = FSMenuItemPath;
    }
}

#pragma mark - Persistence

-(void)addSyncPath:(NSString*)path withName:(NSString*)name {
    [self.syncPaths setObject:path forKey:name];
    [_syncPaths writeToURL:_syncDirectoryStorageURL atomically:YES];
    [self updateMenu];
}

-(void)removeSyncPathWithName:(NSString*)name {
    [self.statusItem.menu removeItem:[_pathMenuItems objectForKey:name]];
    [_pathMenuItems removeObjectForKey:name];
    [self.syncPaths removeObjectForKey:name];
    [_syncPaths writeToURL:_syncDirectoryStorageURL atomically:YES];
    [self updateMenu];
}

-(NSDictionary*)syncPaths {
    if (_syncPaths) {
        return _syncPaths;
    }
    self.syncPaths = [NSMutableDictionary dictionaryWithContentsOfURL:_syncDirectoryStorageURL];
    if (_syncPaths) {
        return _syncPaths;
    }
    self.syncPaths = [NSMutableDictionary dictionary];
    return _syncPaths;
}

@end










