//
//  FSSyncManager.h
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/5/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import <Foundation/Foundation.h>

const NSString *FSMModified = @"Modified";
const NSString *FSMIsDir = @"IsDir";
const NSString *FSMDeleteHistory = @"DeleteHistory";
const NSString *FSMDirectoryInformation = @"DirectoryInformation";

@interface FSSyncManager : NSObject

@property (nonatomic, retain, readonly) NSString *name;
@property (nonatomic, retain, readonly) NSString *path;

-(id)initWithName:(NSString*)name path:(NSString*)path;
-(void)startSyncManager;
-(void)stopSyncManager;

@end
