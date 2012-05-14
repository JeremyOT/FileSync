//
//  FSStatusManager.h
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/13/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FSStatusManager : NSObject <NSMenuDelegate>

@property (nonatomic, getter = isEnabled, readonly) BOOL enabled;

-(void)startSyncing;
-(void)stopSyncing;

-(void)addSyncPath:(NSString*)path withName:(NSString*)name;
-(void)removeSyncPathWithName:(NSString*)name;

@end
