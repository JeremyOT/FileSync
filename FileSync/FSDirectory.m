//
//  FSDirectory.m
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/5/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import "FSDirectory.h"

@interface FSDirectory ()

-(void)indexDirectory:(NSString*)path;

@end

@implementation FSDirectory

#pragma mark - Lifecycle

-(id)init {
    if (self = [super init]) {
        _directoryMap = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(id)initWithPath:(NSString*)path {
    if (self = [self init]) {
        [self indexDirectory:path];
    }
    return self;
}

-(void)dealloc {
    [_directoryMap release];
    [super dealloc];
}

#pragma mark -

-(void)indexDirectory:(NSString*)path {
    [_directoryMap removeAllObjects];
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL isDir = NO;
    for (NSString *file in [manager enumeratorAtPath:[path stringByExpandingTildeInPath]]) {
        [manager fileExistsAtPath:file isDirectory:&isDir];
        [_directoryMap setObject:[NSNumber numberWithBool:isDir] forKey:file];
    }
}

-(NSDictionary *)directoryMap {
    return [NSDictionary dictionaryWithDictionary:_directoryMap];
}

-(void)addFileAtPath:(NSString*)path isDirectory:(BOOL)directory {
    [_directoryMap setObject:[NSNumber numberWithBool:directory] forKey:path];
}

-(BOOL)hasFileAtPath:(NSString*)path {
    return !![_directoryMap objectForKey:path]; 
}

-(BOOL)hasFileAtPath:(NSString*)path isDirectory:(BOOL*)directory {
    NSNumber *isDir = [_directoryMap objectForKey:path];
    *directory = [isDir boolValue];
    return !!isDir;
}

-(BOOL)hasDirectoryAtPath:(NSString*)path {
    return [[_directoryMap objectForKey:path] boolValue];
}

@end
