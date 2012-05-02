//
//  SyncClient.h
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 4/29/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SyncServiceBrowser : NSObject <NSNetServiceBrowserDelegate>

-(BOOL)startWithBlock:(void (^)(NSSet *servers))updatedServersBlock;
-(void)stop;

@end
