//
//  FSSyncManager.m
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/5/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import "FSSyncManager.h"
#import "FSDirectoryObserver.h"
#import "FSSynchronizer.h"
#import "FSConnectionManager.h"

NSString *FSSyncEventTypeKey = @"Type";
NSString *FSSyncEventDataKey = @"Data";
NSString *FSSyncEventPathKey = @"Path";
NSString *FSSyncEventDateKey = @"Date";
NSString *FSSyncEventModified = @"Modified";
NSString *FSSyncEventRemoved = @"Removed";
NSString *FSSyncEventRenamed = @"Renamed";
NSString *FSSyncEventDirectoryCreated = @"DirectoryCreated";
NSString *FSSyncEventAttributesChanged = @"AttributesChanged";
NSString *FSSyncEventModifiedSampleSizeKey = @"SampleSize";
NSString *FSSyncEventModifiedComponentHashKey = @"Hashes";
NSString *FSSyncEventModifiedAttributesKey = @"Attributes";

@interface FSSyncManager () 

@property (nonatomic, retain, readwrite) NSString *name;
@property (nonatomic, retain, readwrite) NSString *path;
@property (nonatomic, retain) FSDirectoryObserver *observer;
@property (nonatomic, retain) NSMutableDictionary *outgoingSynchronizers;
@property (nonatomic, retain) NSMutableDictionary *incomingSynchronizers;
@property (nonatomic, retain) NSMutableDictionary *syncAttributes;
@property (nonatomic, retain) NSMutableArray *syncEventQueue;
@property (nonatomic, retain) NSMutableSet *blockedEvents;
@property (nonatomic, assign) dispatch_queue_t syncLock;

@end

@implementation FSSyncManager

@synthesize name = _name;
@synthesize path = _path;
@synthesize observer = _observer;
@synthesize outgoingSynchronizers = _outgoingSynchronizers;
@synthesize incomingSynchronizers = _incomingSynchronizers;
@synthesize syncAttributes = _syncAttributes;
@synthesize syncEventQueue = _syncEventQueue;
@synthesize blockedEvents = _blockedEvents;
@synthesize syncLock = _syncLock;
@synthesize syncStatusChangedBlock = _syncStatusChangedBlock;

#pragma mark - Lifecycle

-(id)initWithName:(NSString*)name path:(NSString*)path {
    if ((self = [super init])) {
        self.name = name;
        self.path = path;
        _observer = [[FSDirectoryObserver alloc] initWithDirectory:path];
        _outgoingSynchronizers = [[NSMutableDictionary alloc] init];
        _incomingSynchronizers = [[NSMutableDictionary alloc] init];
        _syncAttributes = [[NSMutableDictionary alloc] init];
        _syncEventQueue = [[NSMutableArray alloc] init];
        _blockedEvents = [[NSMutableSet alloc] init];
        _syncLock = dispatch_queue_create("syncLock", 0);
    }
    return self;
}

-(void)dealloc {
    [_name release];
    [_path release];
    [_observer release];
    [_outgoingSynchronizers release];
    [_incomingSynchronizers release];
    [_syncAttributes release];
    [_syncEventQueue release];
    [_blockedEvents release];
    [_syncStatusChangedBlock release];
    dispatch_release(_syncLock);
    [super dealloc];
}

#pragma mark - Synchronization

-(NSInteger)activeSynchronizerCount {
    return [_incomingSynchronizers count] + [_outgoingSynchronizers count];
}

-(NSDictionary*)modificationDates {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSMutableDictionary *modificationDates = [NSMutableDictionary dictionary];
    for (NSString *path in [manager enumeratorAtPath:_path]) {
        if ([path hasSuffix:FSAtomicSuffix]) {
            continue;
        }
        [modificationDates setObject:[[manager attributesOfItemAtPath:[_path stringByAppendingPathComponent:path] error:nil] fileModificationDate] forKey:path];
    }
    return modificationDates;
}

-(NSSet*)requestedPathsForModificationDates:(NSDictionary*)modificationDates sinceTime:(NSDate*)syncTime {
    NSDictionary *localModificationDates = [self modificationDates];
    NSMutableSet *requestedPaths = [NSMutableSet set];
    for (NSString *path in modificationDates) {
        if (![[localModificationDates objectForKey:path] isGreaterThan:[modificationDates objectForKey:path]]) {
            [requestedPaths addObject:path];
        }
    }
    NSFileManager *manager = [NSFileManager defaultManager];
    for (NSString *path in localModificationDates) {
        if (![modificationDates objectForKey:path] && [[localModificationDates objectForKey:path] isLessThan:syncTime]) {
            [manager removeItemAtPath:[_path stringByAppendingPathComponent:path] error:nil];
        }
    }
    return requestedPaths;
}

-(void)completeFileSyncWithDiffData:(NSDictionary*)data {
    NSString *path = [data objectForKey:FSSyncEventPathKey];
    NSArray *diff = [data objectForKey:FSSyncEventDataKey];
    NSString *absolutePath = [_path stringByAppendingPathComponent:path];
    [_blockedEvents addObject:[NSString stringWithFormat:@"%@:%@", FSSyncEventModified, absolutePath]];
    [[_incomingSynchronizers objectForKey:path] updateFileWithDiff:diff];
    [_incomingSynchronizers removeObjectForKey:path];
    [_blockedEvents addObject:[NSString stringWithFormat:@"%@:%@", FSSyncEventAttributesChanged, absolutePath]];
    [[NSFileManager defaultManager] setAttributes:[_syncAttributes objectForKey:absolutePath] ofItemAtPath:absolutePath error:nil];
    [_syncAttributes removeObjectForKey:absolutePath];
    if (_syncStatusChangedBlock) {
        _syncStatusChangedBlock();
    }
}

-(NSDictionary*)diffForComponentData:(NSDictionary*)data {
    NSString *path = [data objectForKey:FSSyncEventPathKey];
    NSSet *components = [data objectForKey:FSSyncEventDataKey];
    DLog(@"Path: %@, Comps: %@", path, components);
    NSArray *diff = [[_outgoingSynchronizers objectForKey:path] diffForComponents:components];
    [_outgoingSynchronizers removeObjectForKey:path];
    if (_syncStatusChangedBlock) {
        _syncStatusChangedBlock();
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            path, FSSyncEventPathKey,
            diff, FSSyncEventDataKey,
            nil];
}

-(void)syncEvents:(NSArray*)events componentSyncBlock:(void (^)(NSDictionary *componentData))componentSyncBlock {
    DLog(@"Syncing %d Remote Events", [events count]);
    NSFileManager *manager = [NSFileManager defaultManager];
    for (NSDictionary *event in events) {
        NSString *type = [event objectForKey:FSSyncEventTypeKey];
        NSString *absolutePath = [_path stringByAppendingPathComponent:[event objectForKey:FSSyncEventPathKey]];
        DLog(@"Event Type: %@ - %@", type, absolutePath);
        if (![[[manager attributesOfItemAtPath:absolutePath error:nil] fileModificationDate] isGreaterThan:[event objectForKey:FSSyncEventDateKey]] ||
            ([type isEqualToString:FSSyncEventRemoved] && ![[manager contentsOfDirectoryAtPath:absolutePath error:nil] count])) {
            if ([type isEqualToString:FSSyncEventRemoved]) {
                [_blockedEvents addObject:[NSString stringWithFormat:@"%@:%@", type, absolutePath]];
                [manager removeItemAtPath:absolutePath error:nil];
            } else if ([type isEqualToString:FSSyncEventAttributesChanged]) {
                [_blockedEvents addObject:[NSString stringWithFormat:@"%@:%@", type, absolutePath]];
                [manager setAttributes:[event objectForKey:FSSyncEventDataKey] ofItemAtPath:absolutePath error:nil];
            } else if ([type isEqualToString:FSSyncEventRenamed]) {
                [_blockedEvents addObject:[NSString stringWithFormat:@"%@:%@", type, absolutePath]];
                [_blockedEvents addObject:[NSString stringWithFormat:@"%@:%@", type, [_path stringByAppendingPathComponent:[event objectForKey:FSSyncEventDataKey]]]];
                [manager moveItemAtPath:absolutePath toPath:[_path stringByAppendingPathComponent:[event objectForKey:FSSyncEventDataKey]] error:nil];
            } else if ([type isEqualToString:FSSyncEventDirectoryCreated]) {
                [_blockedEvents addObject:[NSString stringWithFormat:@"%@:%@", type, absolutePath]];
                [manager createDirectoryAtPath:absolutePath withIntermediateDirectories:YES attributes:[event objectForKey:FSSyncEventDataKey] error:nil];
            } else if ([type isEqualToString:FSSyncEventModified]) {
                NSDictionary *changeData = [event objectForKey:FSSyncEventDataKey];
                DLog(@"Incoming Modified: %@", changeData);
                FSSynchronizer *synchronizer = [[[FSSynchronizer alloc] initWithFile:absolutePath sampleSize:[[changeData objectForKey:FSSyncEventModifiedSampleSizeKey] intValue]] autorelease];
                [_syncAttributes setObject:[changeData objectForKey:FSSyncEventModifiedAttributesKey] forKey:absolutePath];
                [_incomingSynchronizers setObject:synchronizer forKey:[event objectForKey:FSSyncEventPathKey]];
                if (_syncStatusChangedBlock) {
                    _syncStatusChangedBlock();
                }
                componentSyncBlock([NSDictionary dictionaryWithObjectsAndKeys:
                                    [event objectForKey:FSSyncEventPathKey], FSSyncEventPathKey,
                                    [synchronizer existingComponentsForSignature:[changeData objectForKey:FSSyncEventModifiedComponentHashKey]], FSSyncEventDataKey,
                                    nil]);
            }
        } else {
            DLog(@"Skipped");
        }
    }
}

-(void)queueSyncEvent:(NSString*)type path:(NSString*)path data:(id)data {
    NSString *blockedEvent = [NSString stringWithFormat:@"%@:%@", type, path];
    dispatch_sync(_syncLock, ^{
        if ([_blockedEvents containsObject:blockedEvent]) {
            [_blockedEvents removeObject:blockedEvent];
            return;
        }
        DLog(@"%@", blockedEvent);
        [_syncEventQueue addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                    type, FSSyncEventTypeKey,
                                    [path substringFromIndex:[_path length] + 1], FSSyncEventPathKey,
                                    [NSDate date], FSSyncEventDateKey,
                                    data, FSSyncEventDataKey,
                                    nil]];
    });
}

-(void)startSyncManagerWithBlock:(void (^)(NSArray* syncEvents))eventsReceivedBlock {
    [_observer setFileRemovedBlock:^(NSString *path) {
        [self queueSyncEvent:FSSyncEventRemoved path:path data:nil];
    }];
    [_observer setAttributesChangedBlock:^(NSString *path) {
        [self queueSyncEvent:FSSyncEventAttributesChanged path:path data:[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil]];
    }];
    [_observer setFileModifiedBlock:^(NSString *path) {
        FSSynchronizer *synchronizer = [[[FSSynchronizer alloc] initWithFile:path] autorelease];
        [_outgoingSynchronizers setObject:synchronizer forKey:[path substringFromIndex:[_path length] + 1]];
        if (_syncStatusChangedBlock) {
            _syncStatusChangedBlock();
        }
        NSDictionary *changeData = [NSDictionary dictionaryWithObjectsAndKeys:
                                    synchronizer.hashSignature, FSSyncEventModifiedComponentHashKey,
                                    [NSNumber numberWithInt:synchronizer.sampleSize], FSSyncEventModifiedSampleSizeKey,
                                    [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil], FSSyncEventModifiedAttributesKey,
                                    nil];
        DLog(@"Sending Modified: %@", changeData);
        [self queueSyncEvent:FSSyncEventModified path:path data:changeData];
    }];
    [_observer setDirectoryCreatedBlock:^(NSString *path) {
        [self queueSyncEvent:FSSyncEventDirectoryCreated path:path data:[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil]];
    }];
    [_observer setFileRenamedBlock:^(NSString *sourcePath, NSString *destPath) {
        [self queueSyncEvent:FSSyncEventRenamed path:sourcePath data:[destPath substringFromIndex:[_path length] + 1]];
    }];
    [_observer setEventsReceivedBlock:^{
        dispatch_sync(_syncLock, ^{
            NSArray *events = [NSArray arrayWithArray:_syncEventQueue];
            if ([events count]) {
                [_syncEventQueue removeAllObjects];
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    eventsReceivedBlock(events);
                });
            }
        });
    }];
    [_observer start];
}

-(void)stopSyncManager {
    [_observer stop];
}

-(void)forceSyncForPaths:(NSArray*)paths block:(void (^)(NSArray* syncEvents))eventsReceivedBlock {
    dispatch_sync(_syncLock, ^{
        NSArray *events = [NSArray arrayWithArray:_syncEventQueue];
        if ([events count]) {
            [_syncEventQueue removeAllObjects];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                eventsReceivedBlock(events);
            });
        }
    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        BOOL isDir = NO;
        NSFileManager *manager = [NSFileManager defaultManager];
        for (NSString *path in paths) {
            NSString *absolutePath = [_path stringByAppendingPathComponent:path];
            [manager fileExistsAtPath:absolutePath isDirectory:&isDir];
            if (isDir) {
                [self queueSyncEvent:FSSyncEventDirectoryCreated path:absolutePath data:[manager attributesOfItemAtPath:absolutePath error:nil]];
            } else {
                FSSynchronizer *synchronizer = [[[FSSynchronizer alloc] initWithFile:absolutePath] autorelease];
                [_outgoingSynchronizers setObject:synchronizer forKey:path];
                if (_syncStatusChangedBlock) {
                    _syncStatusChangedBlock();
                }
                NSDictionary *changeData = [NSDictionary dictionaryWithObjectsAndKeys:
                                            synchronizer.hashSignature, FSSyncEventModifiedComponentHashKey,
                                            [NSNumber numberWithInt:synchronizer.sampleSize], FSSyncEventModifiedSampleSizeKey,
                                            [[NSFileManager defaultManager] attributesOfItemAtPath:absolutePath error:nil], FSSyncEventModifiedAttributesKey,
                                            nil];
                DLog(@"Sending Modified: %@", changeData);
                [self queueSyncEvent:FSSyncEventModified path:absolutePath data:changeData];
            }
        }
        dispatch_sync(_syncLock, ^{
            NSArray *events = [NSArray arrayWithArray:_syncEventQueue];
            if ([events count]) {
                [_syncEventQueue removeAllObjects];
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    eventsReceivedBlock(events);
                });
            }
        });
    });
}

@end
