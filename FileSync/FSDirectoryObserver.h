//
//  FSDirectoryObserver.h
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/5/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FSDirectoryObserver : NSObject

@property (nonatomic, retain, readonly) NSString *path;
@property (nonatomic, copy) void (^directoryCreatedBlock)(NSString *path);
@property (nonatomic, copy) void (^fileModifiedBlock)(NSString *path);
@property (nonatomic, copy) void (^fileRemovedBlock)(NSString *path);
@property (nonatomic, copy) void (^fileRenamedBlock)(NSString *sourcePath, NSString *destinationPath);
@property (nonatomic, copy) void (^attributesChangedBlock)(NSString *path);
@property (nonatomic, copy) void (^eventsReceivedBlock)();

-(id)initWithDirectory:(NSString*)path;
-(void)start;
-(void)stop;

@end
