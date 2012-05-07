//
//  FSDirectory.h
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/5/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FSDirectory : NSObject {
    NSMutableDictionary *_directoryMap;
}

@property (nonatomic, readonly) NSDictionary *directoryMap;

-(id)initWithPath:(NSString*)path;
-(void)indexDirectory:(NSString*)path;

-(void)addFileAtPath:(NSString*)path isDirectory:(BOOL)directory;
-(BOOL)hasFileAtPath:(NSString*)path;
-(BOOL)hasFileAtPath:(NSString*)path isDirectory:(BOOL*)directory;
-(BOOL)hasDirectoryAtPath:(NSString*)path;

@end
