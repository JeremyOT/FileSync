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

@end

@implementation FSSyncManager

@synthesize name = _name;
@synthesize path = _path;
@synthesize observer = _observer;
@synthesize directory = _directory;
@synthesize synchronizers = _synchronizers;

#pragma mark - Lifecycle

-(id)initWithName:(NSString*)name path:(NSString*)path {
    if ((self = [super init])) {
        self.name = name;
        self.path = path;
        _observer = [[FSDirectoryObserver alloc] initWithDirectory:path];
        _directory = [[FSDirectory alloc] initWithPath:path];
        _synchronizers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(void)dealloc {
    [_name release];
    [_path release];
    [_observer release];
    [_directory release];
    [_synchronizers release];
    [super dealloc];
}

#pragma mark - Sychnronization

-(NSDictionary*)syncDictionary {
    NSDictionary *directoryMap = [_directory directoryMap];
    NSMutableDictionary *syncData = [NSMutableDictionary dictionaryWithCapacity:
}

-(void)removeExcessFilesForDirectoryMap:(NSDictionary*)map {
    NSDictionary *directoryMap = _directory.directoryMap; 
    NSFileManager *manager = [NSFileManager defaultManager];
    for (NSString *path in directoryMap) {
        if (![[map objectForKey:path] isEqualToNumber:[directoryMap objectForKey:path]]) {
            [manager removeItemAtPath:[_path stringByAppendingPathComponent:path] error:nil];
        }
    }
}

-(void)start {
    [_observer start];
}

-(void)stop {
    [_observer stop];
}

@end
