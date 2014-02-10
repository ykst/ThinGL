// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import <Foundation/Foundation.h>
#import "NSData+Digest.h"

@interface NSObject(SimpleArchiver)

// Save to {HOME}/Document/{SHA1(Salt + Class + key)}
- (BOOL)simpleArchiveForKey:(NSString *)key;
// return nil when nothing is found
+ (id)simpleUnarchiveForKey:(NSString *)key;

@end

