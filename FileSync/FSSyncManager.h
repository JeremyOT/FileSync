//
//  FSSyncManager.h
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/5/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FSSyncManager : NSObject

@property (nonatomic, retain, readonly) NSString *name;
@property (nonatomic, retain, readonly) NSString *path;

@end
