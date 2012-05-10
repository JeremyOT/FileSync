//
//  FSConnectionManager.h
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/7/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FSConnectionManager : NSObject

@property (nonatomic, readonly) NSArray *monitoredDirectories;

-(void)addMonitoredDirectory:(NSString*)name atPath:(NSString*)path;
-(void)removeMonitoredDirectory:(NSString*)name;
-(void)startSyncManagerWithBlock:(void (^)(NSArray *services))servicesUpdatedBlock;
-(void)stopSyncManager;

@end
