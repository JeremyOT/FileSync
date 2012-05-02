//
//  SyncClient.h
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 4/29/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SyncServiceBrowser : NSObject <NSNetServiceBrowserDelegate>

@property (nonatomic, readonly) NSSet *allServers;
@property (nonatomic, copy) BOOL (^serverAddedBlock)(NSNetService *server);
@property (nonatomic, copy) void (^serverRemovedBlock)(NSNetService *server);

-(BOOL)startWithBlock:(void (^)(SyncServiceBrowser *browser))serversUpdatedBlock;
-(void)stop;

@end
