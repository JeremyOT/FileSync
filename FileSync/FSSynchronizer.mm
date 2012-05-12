//
//  FSSynchronizer.m
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/2/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import "FSSynchronizer.h"
#import <CommonCrypto/CommonDigest.h>
#include <math.h>
#include <tr1/unordered_map>


#define FSFastHashKey @"FSFastHash"
#define FSSlowHashKey @"FSSlowHash"

@interface FSSynchronizer ()

@property (nonatomic, retain) NSData *data;
@property (nonatomic, retain, readwrite) NSString *path;
@property (nonatomic, readwrite) int sampleSize;
@property (nonatomic, retain) NSArray *signature;
@property (nonatomic, retain) NSMutableDictionary *syncDataMatches;

@end

@implementation FSSynchronizer

@synthesize data = _data;
@synthesize path = _path;
@synthesize signature = _signature;
@synthesize sampleSize = _sampleSize;
@synthesize syncDataMatches = _syncDataMatches;

#pragma mark - Lifecycle

-(id)initWithFile:(NSString *)path {
    if ((self = [super init])) {
        self.path = path;
    }
    return self;
}


-(id)initWithFile:(NSString *)path sampleSize:(int)sampleSize {
    if ((self = [self initWithFile:path])) {
        self.sampleSize = sampleSize;
    }
    return self;
}

-(void)dealloc {
    [_path release];
    [_data release];
    [_signature release];
    [_syncDataMatches release];
    [super dealloc];
}

#pragma mark - Hashing

static unsigned short fastHash(unsigned char *bytes, unsigned int sampleSize) {
    unsigned int counter = 0;
    for (unsigned int i = 0; i < sampleSize; i++) {
        counter = (counter + bytes[i]) % (2 << 15);
    }
    return counter;
}

static NSData* md5Hash(const void *bytes, unsigned int length) {
    unsigned char hash[CC_MD5_DIGEST_LENGTH];
    CC_MD5(bytes, length, hash);
    return [NSData dataWithBytes:hash length:CC_MD5_DIGEST_LENGTH];
}

static void fashHashSwap(unsigned int *hash, unsigned char add, unsigned char subtract) {
    *hash += add;
    *hash %= 2 << 15;
    if (subtract > *hash) {
        *hash = (2 << 15) - subtract + *hash;
    } else {
        *hash -= subtract;
    }
}

#pragma mark - Synchronization

-(void)refresh {
    self.data = nil;
    self.signature = nil;
}

-(NSDictionary*)hashSignature {
    NSMutableDictionary *hashSignature = [NSMutableDictionary dictionaryWithCapacity:[self.signature count]];
    for (NSDictionary *sample in self.signature) {
        [hashSignature setObject:[sample objectForKey:FSSlowHashKey] forKey:[sample objectForKey:FSFastHashKey]];
    }
    return [NSDictionary dictionaryWithDictionary:hashSignature];
}

-(NSData *)data {
    if (_data)
        return _data;
    self.data = [NSData dataWithContentsOfFile:_path];
    if (!_sampleSize) {
        _sampleSize = MAX(MIN([_data length] / 10000, 2 << 15), 2 << 7);
    }
    return _data;
}

-(NSArray*)signature {
    if (_signature) {
        return _signature;
    }
    int length = [self.data length];
    int sampleSize = _sampleSize;
    int sampleCount = ceil((double)length/sampleSize);
    NSMutableArray *signature = [NSMutableArray arrayWithCapacity:sampleCount];
    for (unsigned char *bytes = (unsigned char*)[_data bytes]; length >= 0; bytes += sampleSize, length -= sampleSize) {
        [signature addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedShort:fastHash(bytes, MIN(sampleSize, length))], FSFastHashKey,
                              md5Hash(bytes, MIN(sampleSize, length)), FSSlowHashKey,
                              nil]];
    }
    return [NSArray arrayWithArray:signature];
}

-(NSSet*)existingComponentsForSignature:(NSDictionary*)remoteHashSignature {
    std::tr1::unordered_map<unsigned int, id> hashes;
    for (NSNumber *fastHash in remoteHashSignature) { 
        hashes[[fastHash intValue]] = [remoteHashSignature objectForKey:fastHash];
    }
    NSData *data = self.data;
    NSMutableSet *matches = [NSMutableSet setWithCapacity:[remoteHashSignature count]];
    int length = [data length];
    if (!length) {
        return [NSSet set];
    }
    unsigned char *bytes = (unsigned char*)[data bytes];
    NSData *strongHash = nil;
    self.syncDataMatches = [NSMutableDictionary dictionary];
    int sampleCount = length + _sampleSize - 1;
    unsigned int rollingHash = 0;
    for (int i = 0; i < sampleCount; i++) {
        fashHashSwap(&rollingHash, i < length ? bytes[i] : 0, i >= _sampleSize ? bytes[i - _sampleSize] : 0);
        if ((strongHash = hashes[rollingHash])) {
            if ([strongHash isEqualToData:md5Hash(bytes + MAX(i - _sampleSize + 1, 0), MIN(sampleCount - i, _sampleSize))]) {
                [matches addObject:strongHash];
                [_syncDataMatches setObject:[NSData dataWithBytes:bytes + MAX(i - _sampleSize + 1, 0) length:MIN(sampleCount - i, _sampleSize)] forKey:strongHash];
            }
        }
    }
    return matches;
}

-(NSArray*)diffForComponents:(NSSet*)components {
    int length = [self.data length];
    int sampleSize = _sampleSize;
    
    int sampleCount = ceil((double)length/sampleSize);
    NSMutableArray *diff = [NSMutableArray arrayWithCapacity:sampleCount];
    int i = 0;
    for (NSDictionary *sample in self.signature) {
        if ([diff containsObject:[sample objectForKey:FSSlowHashKey]]) {
            [diff addObject:[sample objectForKey:FSSlowHashKey]];
        } else {
           [diff addObject:[_data subdataWithRange:(NSRange){_sampleSize * i, MIN(_sampleSize, length)}]];
        }
        i++;
        length -= sampleSize;
    }
    return diff;
}

-(void)updateFileWithDiff:(NSArray*)diff {
    NSMutableData *compositeData = [NSMutableData dataWithCapacity:[diff count] * _sampleSize];
    for (NSData *component in diff) {
        if ([component length] == CC_MD5_DIGEST_LENGTH && [_syncDataMatches objectForKey:component]) {
            [compositeData appendData:[_syncDataMatches objectForKey:component]];
        } else {
            [compositeData appendData:component];
        }
    }
    NSString *atomicPath = [[_path stringByDeletingLastPathComponent] stringByAppendingPathComponent:[NSString stringWithFormat:@".%@%@", [_path lastPathComponent], FSAtomicSuffix]];
    [compositeData writeToFile:atomicPath atomically:NO];
    NSFileManager *manager = [NSFileManager defaultManager];
    [manager moveItemAtPath:atomicPath toPath:_path error:nil];
    [manager removeItemAtPath:atomicPath error:nil];
}   

@end
