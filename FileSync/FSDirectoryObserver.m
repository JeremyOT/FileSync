//
//  FSDirectoryObserver.m
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/5/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import "FSDirectoryObserver.h"
#import "FileWatcher.h"

@interface FSDirectoryObserver ()

@property (nonatomic, retain) FileWatcher *watcher;
@property (nonatomic, retain, readwrite) NSString *path;

-(void)eventsReceived:(NSArray*)paths eventFlags:(const FSEventStreamEventFlags*)flags eventIds:(const FSEventStreamEventId*)eventIds count:(int)count;

@end

@implementation FSDirectoryObserver

@synthesize path = _path;
@synthesize watcher = _watcher;
@synthesize directoryCreatedBlock = _directoryCreatedBlock;
@synthesize fileRemovedBlock = _fileRemovedBlock;
@synthesize fileModifiedBlock = _fileModifiedBlock;
@synthesize fileRenamedBlock = _fileRenamedBlock;
@synthesize attributesChangedBlock = _attributesChangedBlock;
@synthesize eventsReceivedBlock = _eventsReceivedBlock;

#pragma mark - Lifecycle

-(id)initWithDirectory:(NSString*)path {
    if ((self = [super init])) {
        self.path = path;
        _watcher = [[FileWatcher alloc] initWithBatchCallbackBlock:^(NSArray *paths, const FSEventStreamEventFlags *flags, const FSEventStreamEventId *eventIds, int count) {
            [self eventsReceived:paths eventFlags:flags eventIds:eventIds count:count];
        }];
    }
    return self;
}

-(void)dealloc {
    [_path release];
    [_watcher release];
    [_directoryCreatedBlock release];
    [_fileModifiedBlock release];
    [_fileRemovedBlock release];
    [_fileRenamedBlock release];
    [_attributesChangedBlock release];
    [_eventsReceivedBlock release];
    [super dealloc];
}

#pragma mark - Service

-(void)start {
    [_watcher openEventStream:[NSArray arrayWithObject:_path] latency:1.0];
}

-(void)stop {
    [_watcher close];
}

#pragma mark - Events

-(void)eventsReceived:(NSArray*)paths eventFlags:(const FSEventStreamEventFlags*)flags eventIds:(const FSEventStreamEventId*)eventIds count:(int)count {
    for (int i = 0; i < count; i++) {
        if (flags[i] & kFSEventStreamEventFlagItemRenamed) {
            BOOL isDir = NO;
            if ([[NSFileManager defaultManager] fileExistsAtPath:[paths objectAtIndex:i] isDirectory:&isDir]) {
                if (isDir) {
                    _directoryCreatedBlock([paths objectAtIndex:i]);
                    _attributesChangedBlock([paths objectAtIndex:i]);
                } else {
                    _fileModifiedBlock([paths objectAtIndex:i]);
                    _attributesChangedBlock([paths objectAtIndex:i]);
                }
            } else {
                _fileRemovedBlock([paths objectAtIndex:i]);
            }
        } else if (flags[i] & kFSEventStreamEventFlagItemRemoved) {
            _fileRemovedBlock([paths objectAtIndex:i]);
        } else if (flags[i] & kFSEventStreamEventFlagItemModified) {
            if (flags[i] & kFSEventStreamEventFlagItemIsFile) {
                _fileModifiedBlock([paths objectAtIndex:i]);
            } else if (flags[i] & kFSEventStreamEventFlagItemIsDir) {
                _directoryCreatedBlock([paths objectAtIndex:i]);
            }
        } else if (flags[i] & kFSEventStreamEventFlagItemCreated) {
            if (flags[i] & kFSEventStreamEventFlagItemIsFile) {
                _fileModifiedBlock([paths objectAtIndex:i]);
                _attributesChangedBlock([paths objectAtIndex:i]);
            } else if (flags[i] & kFSEventStreamEventFlagItemIsDir) {
                _directoryCreatedBlock([paths objectAtIndex:i]);
            }
        } else {
            _attributesChangedBlock([paths objectAtIndex:i]);
        }
    }
    if (_eventsReceivedBlock) 
        _eventsReceivedBlock();
}

@end
