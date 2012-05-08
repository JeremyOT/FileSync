//
//  NSString+Hash.m
//  FileSync
//
//  Created by Jeremy Olmsted-Thompson on 5/7/12.
//  Copyright (c) 2012 JOT. All rights reserved.
//

#import "NSString+Hash.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (Hash)

-(NSString*)hashString {
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256([data bytes], [data length], hash);
    NSString *hashString = [[[NSData dataWithBytes:hash length:CC_SHA256_DIGEST_LENGTH] description] stringByReplacingOccurrencesOfString:@" " withString:@""];
    return [hashString substringWithRange:(NSRange){1, [hashString length] -2}];
}

@end
