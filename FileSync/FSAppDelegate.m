//
//  FSAppDelegate.m
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 4/25/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import "FSAppDelegate.h"
#import "FileWatcher.h"
#import "FSSynchronizer.h"

@interface FSAppDelegate ()

@property (nonatomic,retain) FileWatcher *watcher;
@property (nonatomic,retain) NSString *renameSourcePath;

@end

@implementation FSAppDelegate

@synthesize window = _window;
@synthesize statusItem = _statusItem;
@synthesize statusMenu = _statusMenu;
@synthesize watcher = _watcher;
@synthesize renameSourcePath = _renameSourcePath;

- (void)dealloc
{
    [_statusMenu release];
    [_statusItem release];
    [_watcher close];
    [_watcher release];
    [_renameSourcePath release];
    [super dealloc];
}

-(void)updateMenu {
    [self.statusItem.menu removeAllItems];
    [self.statusItem.menu addItemWithTitle:[[NSHost currentHost] localizedName] action:NULL keyEquivalent:@""];
    [self.statusItem.menu addItem:[NSMenuItem separatorItem]];
//    for (NSString *host in _remoteServices) {
//        [self.statusItem.menu addItemWithTitle:host action:NULL keyEquivalent:@""];
//    }
}

-(void)sycnDir:(NSString*)source withDir:(NSString*)sink forEvent:(FSEventStreamEventFlags)flags {
    [[NSFileManager defaultManager] createDirectoryAtPath:sink withIntermediateDirectories:YES attributes:[[NSFileManager defaultManager] attributesOfItemAtPath:source error:nil] error:nil];
    [[NSFileManager defaultManager] setAttributes:[[NSFileManager defaultManager] attributesOfItemAtPath:source error:nil] ofItemAtPath:sink error:nil];
}

-(void)syncFile:(NSString*)source withFile:(NSString*)sink forEvent:(FSEventStreamEventFlags)flags {
//        FSSynchronizer *inSync = [[FSSynchronizer alloc] initWithFile:source];
//        FSSynchronizer *outSync = [[FSSynchronizer alloc] initWithFile:sink];
//        NSSet *diff = [outSync diffForSignature:inSync.hashSignature];
//        NSArray *components = [inSync componentsForDiff:diff];
//        [outSync updateFileWithComponents:components];
//        [inSync release];
//        [outSync release];
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
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.title = @"FileSync";
    self.statusItem.menu = _statusMenu;
    self.statusItem.highlightMode = YES;
    _watcher = [[FileWatcher alloc] init];
    [_watcher openEventStream:[NSArray arrayWithObject:@"/Users/jeremyot/Desktop"] latency:1];
}

@end
