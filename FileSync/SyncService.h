//
//  SyncService.h
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 4/26/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SyncService;
@class SyncConnection;

@interface SyncService : NSObject <NSNetServiceDelegate>

@property (nonatomic, copy, readonly) NSString *serviceName;
@property (nonatomic, assign, readonly) uint16_t port; 
@property (nonatomic, copy) void (^acceptBlock)(SyncConnection*);
@property (nonatomic, copy) void (^errorBlock)(SyncService*, NSNetService*, NSDictionary*);

-(id)initWithName:(NSString*)name;
-(BOOL)startWithAcceptBlock:(void (^)(SyncConnection *connection))acceptBlock;
-(void)stop;

@end
