//
//  FileWatcher.h
//  FSMonitor
//
//  Created by Jeremy Olmsted-Thompson on 8/23/11.
//  Copyright 2011 JOT. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FileWatcher : NSObject {
    void (^_callbackBlock)(NSString*, FSEventStreamEventFlags, FSEventStreamEventId);
    void (^_batchCallbackBlock)(NSArray *paths, const FSEventStreamEventFlags flagArray[], const FSEventStreamEventId eventIdArray[], int count);  
    FSEventStreamRef _eventStream;
}

-(id)initWithBlock:(void (^)(NSString*, FSEventStreamEventFlags, FSEventStreamEventId))block;
-(id)initWithBatchCallbackBlock:(void (^)(NSArray*, const FSEventStreamEventFlags*, const FSEventStreamEventId*, int))block;
-(void)openEventStream:(NSArray*)pathsToWatch latency:(NSTimeInterval)latency;
-(void)close;

@end
