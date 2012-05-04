//
//  FSSynchronizer.h
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/2/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

@interface FSSynchronizer : NSObject

@property (nonatomic, retain, readonly) NSString *path;
@property (nonatomic, retain, readonly) NSDictionary *hashSignature;

-(id)initWithFile:(NSString*)path;

-(NSSet*)diffForSignature:(NSDictionary*)remoteSignature;
-(NSArray*)componentsForDiff:(NSSet*)diff;
-(void)updateFileWithComponents:(NSArray*)components;

@end
