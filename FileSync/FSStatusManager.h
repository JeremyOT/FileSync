//
//  FSStatusManager.h
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/13/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum {
    FSSyncStateIdle,
    FSSyncStateSyncing,
    FSSyncStatePaused,
} FSSyncState;

@interface FSStatusManager : NSObject <NSMenuDelegate>

@property (nonatomic, readonly) FSSyncState currentState;

-(void)startSyncing;
-(void)stopSyncing;

-(void)addSyncPath:(NSString*)path withName:(NSString*)name;
-(void)removeSyncPathWithName:(NSString*)name;

@end
