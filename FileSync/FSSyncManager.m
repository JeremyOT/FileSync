//
//  FSSyncManager.m
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/5/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import "FSSyncManager.h"
#import "FSDirectoryObserver.h"
#import "FSDirectory.h"

const NSString *FSFileIsDirectory = @"Directory";
const NSString *FSFileAttributes = @"Attributes";

@interface FSSyncManager () 

@property (nonatomic, retain, readwrite) NSString *name;
@property (nonatomic, retain, readwrite) NSString *path;
@property (nonatomic, retain) FSDirectoryObserver *observer;
@property (nonatomic, retain) FSDirectory *directory;
@property (nonatomic, retain) NSMutableDictionary *synchronizers;
@property (nonatomic, retain) NSMutableDictionary *deleteHistory;

@end

@implementation FSSyncManager

@synthesize name = _name;
@synthesize path = _path;
@synthesize observer = _observer;
@synthesize directory = _directory;
@synthesize synchronizers = _synchronizers;
@synthesize deleteHistory = _deleteHistory;

#pragma mark - Lifecycle

-(id)initWithName:(NSString*)name path:(NSString*)path {
    if ((self = [super init])) {
        self.name = name;
        self.path = path;
        _observer = [[FSDirectoryObserver alloc] initWithDirectory:path];
        _directory = [[FSDirectory alloc] initWithPath:path];
        _synchronizers = [[NSMutableDictionary alloc] init];
        self.deleteHistory = [NSMutableDictionary dictionaryWithContentsOfFile:path];
        if (_deleteHistory) {
            _deleteHistory = [[NSMutableDictionary alloc] init];
        }
    }
    return self;
}

-(void)dealloc {
    [_name release];
    [_path release];
    [_observer release];
    [_directory release];
    [_synchronizers release];
    [_deleteHistory release];
    [super dealloc];
}

#pragma mark - Sychnronization

-(NSDictionary*)syncDictionary {
    NSDictionary *directoryMap = [_directory directoryMap];
    NSFileManager *manager = [NSFileManager defaultManager];
    NSMutableDictionary *directoryInformation = [NSMutableDictionary dictionaryWithCapacity:[directoryMap count]];
    for (NSString *path in directoryMap) {
        [directoryInformation setObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                         [[manager attributesOfItemAtPath:[_path stringByAppendingPathComponent:path] error:nil] fileModificationDate], FSMModified,
                                         [directoryMap objectForKey:path], FSMIsDir,
                                         nil] forKey:path];
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
            _deleteHistory, FSMDeleteHistory,
            directoryInformation, FSMDirectoryInformation,
            nil];
}

-(NSSet*)requestedPathsForSyncDictionary:(NSDictionary*)syncDictionary {
    NSDictionary *deleteHistory = [syncDictionary objectForKey:FSMDeleteHistory];
    NSFileManager *manager = [NSFileManager defaultManager];
    for (NSString *path in deleteHistory) {
        NSString *absolutePath = [_path stringByAppendingPathComponent:path];
        if ([manager fileExistsAtPath:absolutePath] && [[[manager attributesOfItemAtPath:absolutePath error:nil] fileModificationDate] isLessThan:[deleteHistory objectForKey:path]]) {
            [manager removeItemAtPath:absolutePath error:nil];
        }
    }
    NSDictionary *directoryInformation = [syncDictionary objectForKey:FSMDirectoryInformation];
    NSMutableSet *syncPaths = [NSMutableSet set];
    for (NSString *path in directoryInformation) {
        NSString *absolutePath = [_path stringByAppendingPathComponent:path];
        if ([_deleteHistory objectForKey:path] && [[_deleteHistory objectForKey:path] isGreaterThanOrEqualTo:[[directoryInformation objectForKey:path] objectForKey:FSMModified]]) {
            continue;
        }
        if ([manager fileExistsAtPath:absolutePath] && [[[manager attributesOfItemAtPath:absolutePath error:nil] fileModificationDate] isGreaterThanOrEqualTo:[[directoryInformation objectForKey:path] objectForKey:FSMModified]]) {
            continue;
        }
        [syncPaths addObject:path];
    }
    return syncPaths;
}

-(void)startSyncManager {
    [_observer setFileRemovedBlock:^(NSString *path) {
        
    }];
    [_observer start];
}

-(void)stopSyncManager {
    [_observer stop];
}

@end
