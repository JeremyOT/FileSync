//
//  FSDirectoryObserver.m
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/5/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import "FSDirectoryObserver.h"
#import "FileWatcher.h"
#import "FSSynchronizer.h"

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
        NSString *path = [paths objectAtIndex:i];
        if ([path hasSuffix:FSAtomicSuffix]) {
            continue;
        }
        if (flags[i] & kFSEventStreamEventFlagItemRenamed) {
            BOOL isDir = NO;
            NSFileManager *manager = [NSFileManager defaultManager];
            if ([manager fileExistsAtPath:path isDirectory:&isDir]) {
                if (isDir) {
                    _directoryCreatedBlock(path);
                    for (NSString *subPath in [manager enumeratorAtPath:path]) {
                        if ([subPath hasSuffix:FSAtomicSuffix]) {
                            continue;
                        }
                        NSString *filePath = [path stringByAppendingPathComponent:subPath];
                        [manager fileExistsAtPath:filePath isDirectory:&isDir];
                        if (isDir) {
                            _directoryCreatedBlock(filePath);
                        } else {
                            _fileModifiedBlock(filePath);
                            _attributesChangedBlock(filePath);
                        }
                    }
                } else {
                    _fileModifiedBlock(path);
                    _attributesChangedBlock(path);
                }
            } else {
                if (i+1 < count && [manager fileExistsAtPath:[paths objectAtIndex:i+1]]) {
                    _fileRenamedBlock(path, [paths objectAtIndex:++i]);
                } else {
                    _fileRemovedBlock(path);
                }
            }
        } else if (flags[i] & kFSEventStreamEventFlagItemRemoved) {
            _fileRemovedBlock(path);
        } else if (flags[i] & kFSEventStreamEventFlagItemModified) {
            if (flags[i] & kFSEventStreamEventFlagItemIsFile) {
                _fileModifiedBlock(path);
            } else if (flags[i] & kFSEventStreamEventFlagItemIsDir) {
                _directoryCreatedBlock(path);
            }
        } else if (flags[i] & kFSEventStreamEventFlagItemCreated) {
            if (flags[i] & kFSEventStreamEventFlagItemIsFile) {
                _fileModifiedBlock(path);
                _attributesChangedBlock(path);
            } else if (flags[i] & kFSEventStreamEventFlagItemIsDir) {
                _directoryCreatedBlock(path);
            }
        } else {
            _attributesChangedBlock(path);
        }
    }
    if (_eventsReceivedBlock) {
        _eventsReceivedBlock();
    }
}

@end
