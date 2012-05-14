//
//  FSAppDelegate.m
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 4/25/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import "FSAppDelegate.h"
#import "FSStatusManager.h"

@interface FSAppDelegate ()

@property (nonatomic,retain) FSStatusManager *statusManager;

@end

@implementation FSAppDelegate

@synthesize window = _window;
@synthesize statusManager = _statusManager;

- (void)dealloc
{
    [_statusManager release];
    [super dealloc];
}

-(void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSString *syncSource = @"/Users/jeremyot/Desktop/SyncTest";
    _statusManager = [[FSStatusManager alloc] init];
    [_statusManager addSyncPath:syncSource withName:@"TestDir"];
    [_statusManager startSyncing];
}

-(void)applicationWillTerminate:(NSNotification *)notification {
    [_statusManager stopSyncing];
    self.statusManager = nil;
}

@end
