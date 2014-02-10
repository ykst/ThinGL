// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import <Foundation/Foundation.h>
#import "TGLDevice.h"

@interface TGLTexture2D : NSObject
@property (nonatomic, readonly) GLuint name;
@property (nonatomic, readonly) CGSize size;

+ (TGLTexture2D *)createWithSize:(CGSize)size withInternalFormat:(GLenum)internal_format withSmooth:(BOOL)smooth;

- (void)bind;
+ (void)unbind;
@end

