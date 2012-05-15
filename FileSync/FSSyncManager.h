//
//  FSSyncManager.h
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/5/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FSSyncManager : NSObject

@property (nonatomic, retain, readonly) NSString *name;
@property (nonatomic, retain, readonly) NSString *path;
@property (nonatomic, readonly) NSInteger activeSynchronizerCount;
@property (nonatomic, copy) void (^syncStatusChangedBlock)();

-(id)initWithName:(NSString*)name path:(NSString*)path;

-(NSDictionary*)modificationDates;
-(NSSet*)requestedPathsForModificationDates:(NSDictionary*)modificationDates sinceTime:(NSDate*)syncTime;
-(void)completeFileSyncWithDiffData:(NSDictionary*)data;
-(NSDictionary*)diffForComponentData:(NSDictionary*)data;
-(void)syncEvents:(NSArray*)events componentSyncBlock:(void (^)(NSDictionary *componentData))componentSyncBlock;
-(void)queueSyncEvent:(NSString*)type path:(NSString*)path data:(id)data;

-(void)startSyncManagerWithBlock:(void (^)(NSArray* syncEvents))eventsReceivedBlock;
-(void)stopSyncManager;


-(void)forceSyncForPaths:(NSArray*)paths block:(void (^)(NSArray* syncEvents))eventsReceivedBlock;

@end
