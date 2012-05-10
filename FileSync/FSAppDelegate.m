//
//  FSAppDelegate.m
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 4/25/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import "FSAppDelegate.h"
#import "FSConnectionManager.h"
#import "FileWatcher.h"

@interface FSAppDelegate ()

@property (nonatomic,retain) NSString *renameSourcePath;

@end

@implementation FSAppDelegate

@synthesize window = _window;
@synthesize statusItem = _statusItem;
@synthesize statusMenu = _statusMenu;
@synthesize renameSourcePath = _renameSourcePath;

- (void)dealloc
{
    [_statusMenu release];
    [_statusItem release];
    [_renameSourcePath release];
    [super dealloc];
}

-(void)awakeFromNib {
    NSString *syncSource = @"/Users/jeremyot/Desktop/SyncTest";
    FSConnectionManager *manager = [[FSConnectionManager alloc] init];
    [manager addMonitoredDirectory:@"TestDir" atPath:syncSource];
    [manager startSyncManagerWithBlock:^(NSArray *services) {
        [self.statusItem.menu removeAllItems];
        [self.statusItem.menu addItemWithTitle:[[NSHost currentHost] localizedName] action:NULL keyEquivalent:@""];
        [self.statusItem.menu addItem:[NSMenuItem separatorItem]];
        for (NSString *service in [services sortedArrayUsingSelector:@selector(localizedDescription)]) {
            [self.statusItem.menu addItemWithTitle:service action:NULL keyEquivalent:@""];
        }
        DLog(@"Updated Services: %@", services);
    }];
}

@end
