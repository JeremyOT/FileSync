//
//  FSSynchronizer.h
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/2/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#define FSAtomicSuffix @"____"

@interface FSSynchronizer : NSObject

@property (nonatomic, retain, readonly) NSString *path;
@property (nonatomic, retain, readonly) NSDictionary *hashSignature;
@property (nonatomic, readonly) int sampleSize;

-(id)initWithFile:(NSString*)path;
-(id)initWithFile:(NSString *)path sampleSize:(int)sampleSize;

-(NSSet*)existingComponentsForSignature:(NSDictionary*)remoteSignature;
-(NSArray*)diffForComponents:(NSSet*)components;
-(void)updateFileWithDiff:(NSArray*)diff;

@end
