//
//  FSTest.m
//  FSTest
//
//  Created by Jeremy Olmsted-Thompson on 5/8/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import "FSTest.h"
#import "FSSynchronizer.h"

@interface FSTest ()

@property (nonatomic, retain) NSString *tempDir;

@end

@implementation FSTest

NSString *smallSource = @"SmallSource";
NSString *largeSource = @"LargeSource";
NSString *smallDest = @"SmallDest";
NSString *largeDest = @"LargeDest";

@synthesize tempDir;

- (void)setUp
{
    [super setUp];
    tempDir = NSTemporaryDirectory();
    NSMutableData *largeData = [NSMutableData dataWithCapacity:sizeof(uint32_t) * 1024 * 1024 * 10];
    uint32_t rand = arc4random();
    for (int i = 0; i < 1024 * 1024; i++) {
        [largeData appendBytes:&rand length:sizeof(uint32_t)];
        rand = arc4random();
    }
    [@"Short test text string" writeToFile:[tempDir stringByAppendingPathComponent:smallSource] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [@"Short test text string" writeToFile:[tempDir stringByAppendingPathComponent:smallDest] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [largeData writeToFile:[tempDir stringByAppendingPathComponent:largeSource] atomically:YES];
    [largeData writeToFile:[tempDir stringByAppendingPathComponent:largeDest] atomically:YES];
}

- (void)tearDown
{
    // Tear-down code here.
    [[NSFileManager defaultManager] removeItemAtPath:[tempDir stringByAppendingPathComponent:smallSource] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[tempDir stringByAppendingPathComponent:smallDest] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[tempDir stringByAppendingPathComponent:largeSource] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[tempDir stringByAppendingPathComponent:largeDest] error:nil];
    [super tearDown];
}

-(void)testSyncIdentical {
    FSSynchronizer *smallSourceSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:smallSource]];
    FSSynchronizer *smallDestSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:smallDest]];
    
    NSDictionary *hashSignature = [smallSourceSynchronizer hashSignature];
    NSSet *components = [smallDestSynchronizer existingComponentsForSignature:hashSignature];
    NSArray *diff = [smallSourceSynchronizer diffForComponents:components];
    [smallDestSynchronizer updateFileWithDiff:diff];
    [smallSourceSynchronizer release];
    [smallDestSynchronizer release];
    
    STAssertTrue([[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:smallSource]] isEqualToData:[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:smallDest]]], @"Small unchanged sync failed.");
    
    FSSynchronizer *largeSourceSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:largeSource]];
    FSSynchronizer *largeDestSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:largeDest]];
    
    hashSignature = [largeSourceSynchronizer hashSignature];
    components = [largeDestSynchronizer existingComponentsForSignature:hashSignature];
    diff = [largeSourceSynchronizer diffForComponents:components];
    [largeDestSynchronizer updateFileWithDiff:diff];
    [largeSourceSynchronizer release];
    [largeDestSynchronizer release];
    
    STAssertTrue([[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:largeSource]] isEqualToData:[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:largeDest]]], @"Large unchanged sync failed.");
}

-(void)testSyncToMissing {
    FSSynchronizer *smallSourceSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:smallSource]];
    FSSynchronizer *smallDestSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:smallDest]];
    [[NSFileManager defaultManager] removeItemAtPath:[tempDir stringByAppendingPathComponent:smallDest] error:nil];
    NSDictionary *hashSignature = [smallSourceSynchronizer hashSignature];
    NSSet *components = [smallDestSynchronizer existingComponentsForSignature:hashSignature];
    NSArray *diff = [smallSourceSynchronizer diffForComponents:components];
    [smallDestSynchronizer updateFileWithDiff:diff];
    [smallSourceSynchronizer release];
    [smallDestSynchronizer release];
    
    STAssertTrue([[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:smallSource]] isEqualToData:[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:smallDest]]], @"Small unchanged sync failed.");
    
    FSSynchronizer *largeSourceSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:largeSource]];
    FSSynchronizer *largeDestSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:largeDest]];
    [[NSFileManager defaultManager] removeItemAtPath:[tempDir stringByAppendingPathComponent:largeDest] error:nil];
    hashSignature = [largeSourceSynchronizer hashSignature];
    components = [largeDestSynchronizer existingComponentsForSignature:hashSignature];
    diff = [largeSourceSynchronizer diffForComponents:components];
    [largeDestSynchronizer updateFileWithDiff:diff];
    [largeSourceSynchronizer release];
    [largeDestSynchronizer release];
    
    STAssertTrue([[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:largeSource]] isEqualToData:[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:largeDest]]], @"Large unchanged sync failed.");
}

-(void)testSyncToTrimmedStart {
    FSSynchronizer *smallSourceSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:smallSource]];
    FSSynchronizer *smallDestSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:smallDest]];
    
    NSMutableData *smallData = [NSMutableData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:smallDest]];
    [smallData replaceBytesInRange:(NSRange){0, [smallData length] / 2} withBytes:NULL length:0];
    [smallData writeToFile:[tempDir stringByAppendingPathComponent:smallDest] atomically:YES];
    
    NSDictionary *hashSignature = [smallSourceSynchronizer hashSignature];
    NSSet *components = [smallDestSynchronizer existingComponentsForSignature:hashSignature];
    NSArray *diff = [smallSourceSynchronizer diffForComponents:components];
    [smallDestSynchronizer updateFileWithDiff:diff];
    [smallSourceSynchronizer release];
    [smallDestSynchronizer release];
    
    STAssertTrue([[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:smallSource]] isEqualToData:[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:smallDest]]], @"Small sync to truncated start failed.");
    
    FSSynchronizer *largeSourceSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:largeSource]];
    FSSynchronizer *largeDestSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:largeDest]];
    
    NSMutableData *largeData = [NSMutableData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:largeDest]];
    [largeData replaceBytesInRange:(NSRange){0, [largeData length] / 2} withBytes:NULL length:0];
    [largeData writeToFile:[tempDir stringByAppendingPathComponent:largeDest] atomically:YES];
    
    hashSignature = [largeSourceSynchronizer hashSignature];
    components = [largeDestSynchronizer existingComponentsForSignature:hashSignature];
    diff = [largeSourceSynchronizer diffForComponents:components];
    [largeDestSynchronizer updateFileWithDiff:diff];
    [largeSourceSynchronizer release];
    [largeDestSynchronizer release];
    
    STAssertTrue([[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:largeSource]] isEqualToData:[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:largeDest]]], @"Large sync to truncated start failed.");
}

-(void)testSyncToTrimmedEnd {
    FSSynchronizer *smallSourceSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:smallSource]];
    FSSynchronizer *smallDestSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:smallDest]];
    
    NSMutableData *smallData = [NSMutableData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:smallDest]];
    [smallData replaceBytesInRange:(NSRange){[smallData length] / 2, [smallData length] - ([smallData length] / 2)} withBytes:NULL length:0];
    [smallData writeToFile:[tempDir stringByAppendingPathComponent:smallDest] atomically:YES];
    
    NSDictionary *hashSignature = [smallSourceSynchronizer hashSignature];
    NSSet *components = [smallDestSynchronizer existingComponentsForSignature:hashSignature];
    NSArray *diff = [smallSourceSynchronizer diffForComponents:components];
    [smallDestSynchronizer updateFileWithDiff:diff];
    [smallSourceSynchronizer release];
    [smallDestSynchronizer release];
    
    STAssertTrue([[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:smallSource]] isEqualToData:[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:smallDest]]], @"Small sync to truncated end failed.");
    
    FSSynchronizer *largeSourceSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:largeSource]];
    FSSynchronizer *largeDestSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:largeDest]];
    
    NSMutableData *largeData = [NSMutableData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:largeDest]];
    [largeData replaceBytesInRange:(NSRange){[largeData length] / 2, [largeData length] - ([largeData length] / 2)} withBytes:NULL length:0];
    [largeData writeToFile:[tempDir stringByAppendingPathComponent:largeDest] atomically:YES];
    
    hashSignature = [largeSourceSynchronizer hashSignature];
    components = [largeDestSynchronizer existingComponentsForSignature:hashSignature];
    diff = [largeSourceSynchronizer diffForComponents:components];
    [largeDestSynchronizer updateFileWithDiff:diff];
    [largeSourceSynchronizer release];
    [largeDestSynchronizer release];
    
    STAssertTrue([[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:largeSource]] isEqualToData:[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:largeDest]]], @"Large sync to truncated end failed.");
}

-(void)testSyncFromTrimmedStart {
    FSSynchronizer *smallSourceSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:smallSource]];
    FSSynchronizer *smallDestSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:smallDest]];
    
    NSMutableData *smallData = [NSMutableData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:smallSource]];
    [smallData replaceBytesInRange:(NSRange){0, [smallData length] / 2} withBytes:NULL length:0];
    [smallData writeToFile:[tempDir stringByAppendingPathComponent:smallSource] atomically:YES];
    
    NSDictionary *hashSignature = [smallSourceSynchronizer hashSignature];
    NSSet *components = [smallDestSynchronizer existingComponentsForSignature:hashSignature];
    NSArray *diff = [smallSourceSynchronizer diffForComponents:components];
    [smallDestSynchronizer updateFileWithDiff:diff];
    [smallSourceSynchronizer release];
    [smallDestSynchronizer release];
    
    STAssertTrue([[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:smallSource]] isEqualToData:[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:smallDest]]], @"Small sync from truncated end failed.");
    
    FSSynchronizer *largeSourceSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:largeSource]];
    FSSynchronizer *largeDestSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:largeDest]];
    
    NSMutableData *largeData = [NSMutableData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:largeSource]];
    [largeData replaceBytesInRange:(NSRange){0, [largeData length] / 2} withBytes:NULL length:0];
    [largeData writeToFile:[tempDir stringByAppendingPathComponent:largeSource] atomically:YES];
    
    hashSignature = [largeSourceSynchronizer hashSignature];
    components = [largeDestSynchronizer existingComponentsForSignature:hashSignature];
    diff = [largeSourceSynchronizer diffForComponents:components];
    [largeDestSynchronizer updateFileWithDiff:diff];
    [largeSourceSynchronizer release];
    [largeDestSynchronizer release];
    
    STAssertTrue([[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:largeSource]] isEqualToData:[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:largeDest]]], @"Large sync from truncated end failed.");
}

-(void)testSyncFromTrimmedEnd {
    FSSynchronizer *smallSourceSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:smallSource]];
    FSSynchronizer *smallDestSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:smallDest]];
    
    NSMutableData *smallData = [NSMutableData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:smallSource]];
    [smallData replaceBytesInRange:(NSRange){[smallData length] / 2, [smallData length] - ([smallData length] / 2)} withBytes:NULL length:0];
    [smallData writeToFile:[tempDir stringByAppendingPathComponent:smallSource] atomically:YES];
    
    NSDictionary *hashSignature = [smallSourceSynchronizer hashSignature];
    NSSet *components = [smallDestSynchronizer existingComponentsForSignature:hashSignature];
    NSArray *diff = [smallSourceSynchronizer diffForComponents:components];
    [smallDestSynchronizer updateFileWithDiff:diff];
    [smallSourceSynchronizer release];
    [smallDestSynchronizer release];
    
    STAssertTrue([[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:smallSource]] isEqualToData:[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:smallDest]]], @"Small turncate end sync failed.");
    
    FSSynchronizer *largeSourceSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:largeSource]];
    FSSynchronizer *largeDestSynchronizer = [[FSSynchronizer alloc] initWithFile:[tempDir stringByAppendingPathComponent:largeDest]];
    
    NSMutableData *largeData = [NSMutableData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:largeSource]];
    [largeData replaceBytesInRange:(NSRange){[largeData length] / 2, [largeData length] - ([largeData length] / 2)} withBytes:NULL length:0];
    [largeData writeToFile:[tempDir stringByAppendingPathComponent:largeSource] atomically:YES];
    
    hashSignature = [largeSourceSynchronizer hashSignature];
    components = [largeDestSynchronizer existingComponentsForSignature:hashSignature];
    diff = [largeSourceSynchronizer diffForComponents:components];
    [largeDestSynchronizer updateFileWithDiff:diff];
    [largeSourceSynchronizer release];
    [largeDestSynchronizer release];
    
    STAssertTrue([[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:largeSource]] isEqualToData:[NSData dataWithContentsOfFile:[tempDir stringByAppendingPathComponent:largeDest]]], @"Large turncate end sync failed.");
}
@end
