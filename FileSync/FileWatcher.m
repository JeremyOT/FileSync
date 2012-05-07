//
//  FileWatcher.m
//  FSMonitor
//
//  Created by Jeremy Olmsted-Thompson on 8/23/11.
//  Copyright 2011 JOT. All rights reserved.
//

#import "FileWatcher.h"

@implementation FileWatcher

static void fsevents_callback(ConstFSEventStreamRef streamRef,
                              void *userData,
                              size_t numEvents,
                              void *eventPaths,
                              const FSEventStreamEventFlags eventFlags[],
                              const FSEventStreamEventId eventIds[]) {
    if (((FileWatcher*)userData)->_batchCallbackBlock) {
        ((FileWatcher*)userData)->_batchCallbackBlock((NSArray *)eventPaths, eventFlags, eventIds, numEvents);
    } else {
        for(int i = 0; i < numEvents; i++) {
            ((FileWatcher*)userData)->_callbackBlock([(NSArray *)eventPaths objectAtIndex:i], eventFlags[i], eventIds[i]);
        }
    }
}

#pragma mark -
#pragma mark Lifecycle

-(id)initWithBlock:(void (^)(NSString*, FSEventStreamEventFlags, FSEventStreamEventId))block {
    if ((self = [super init])) {
        _callbackBlock = [block copy];
    }
    return self;
}

-(id)initWithBatchCallbackBlock:(void (^)(NSArray *, const FSEventStreamEventFlags *, const FSEventStreamEventId *, int))block {
    if ((self = [super init])) {
        _batchCallbackBlock = [block copy];
    }
    return self;
}

-(id)init {
    return [self initWithBlock:^(NSString* changed, FSEventStreamEventFlags flags, FSEventStreamEventId eventId) {
        NSMutableArray *actions = [NSMutableArray array];
        if (kFSEventStreamEventFlagItemCreated & flags) {
            [actions addObject:@"Created"];
        }
        if (kFSEventStreamEventFlagItemRemoved & flags) {
            [actions addObject:@"Removed"];
        }
        if (kFSEventStreamEventFlagItemInodeMetaMod & flags) {
            [actions addObject:@"InodeMetaMod"];
        }
        if (kFSEventStreamEventFlagItemRenamed & flags) {
            [actions addObject:@"Renamed"];
        }
        if (kFSEventStreamEventFlagItemModified & flags) {
            [actions addObject:@"Modified"];
        }
        if (kFSEventStreamEventFlagItemFinderInfoMod & flags) {
            [actions addObject:@"FinderInfoMod"];
        }
        if (kFSEventStreamEventFlagItemChangeOwner & flags) {
            [actions addObject:@"Chown"];
        }
        if (kFSEventStreamEventFlagItemXattrMod & flags) {
            [actions addObject:@"XattrMod"];
        }
        if (kFSEventStreamEventFlagItemIsFile & flags) {
            [actions addObject:@"File"];
        }
        if (kFSEventStreamEventFlagItemIsDir & flags) {
            [actions addObject:@"Dir"];
        }
        if (kFSEventStreamEventFlagItemIsSymlink & flags) {
            [actions addObject:@"Symlink"];
        }
        DLog(@"%@ <%d>: %@", changed, eventId, [actions componentsJoinedByString:@" & "]);
    }];
}

-(void)dealloc {
    [self close];
    [_callbackBlock release];
    [_batchCallbackBlock release];
    [super dealloc];
}

#pragma mark -
#pragma mark Stream

-(void)openEventStream:(NSArray*)pathsToWatch latency:(NSTimeInterval)latency {
    [self close];
    if (![pathsToWatch count]) {
        pathsToWatch = [NSArray arrayWithObject:@"/"];
    }
    FSEventStreamContext context = {0, (void *)self, NULL, NULL, NULL};
    _eventStream = FSEventStreamCreate(NULL,
                                       &fsevents_callback,
                                       &context,
                                       (CFArrayRef) pathsToWatch,
                                       kFSEventStreamEventIdSinceNow,
                                       (CFAbsoluteTime) latency,
                                       kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents
                                       );
    
    FSEventStreamScheduleWithRunLoop(_eventStream,
                                     CFRunLoopGetCurrent(),
                                     kCFRunLoopDefaultMode);
    FSEventStreamStart(_eventStream);
}

-(void)close {
    if (_eventStream) {
        FSEventStreamStop(_eventStream);
        FSEventStreamInvalidate(_eventStream);
        _eventStream = NULL;
    }
}

#pragma mark -

@end