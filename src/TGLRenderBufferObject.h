// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import <Foundation/Foundation.h>
#import "TGLDevice.h"
#import "TGLBindable.h"

@interface TGLRenderBufferObject : NSObject<TGLBindable>

@property (nonatomic, readonly) GLenum internal_format;
@property (nonatomic, readonly) CGSize size;

+ (TGLRenderBufferObject *)createRenderBufferObject;

+ (TGLRenderBufferObject *)createWithSize:(CGSize)size withInternalFormat:(GLenum)internal_format;

+ (TGLRenderBufferObject *)createWithEAGLContext:(EAGLContext *)context withLayer:(CAEAGLLayer *)layer;

@end

