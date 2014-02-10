// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

// Acknowledgement: http://blog.heartofsword.net/archives/542

#import <Foundation/Foundation.h>

@interface NSData(Digest)
+ (NSData *) utf8Data: (NSString *) string;
- (NSData *) sha1Digest;
- (NSData *) md5Digest;
- (NSString *) hexString;
- (NSString *) sha1String;
@end

