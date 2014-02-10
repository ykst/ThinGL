// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import <Foundation/Foundation.h>
#import "TGLBindable.h"
#import "TGLMappedTexture2D.h"
#import "TGLRenderBufferObject.h"

@interface TGLFrameBufferObject : NSObject<TGLBindable>

@property (nonatomic, readonly) CGSize size;
// XXX: dirty shortcuts
@property (nonatomic, readonly) TGLMappedTexture2D *mapped_texture;
@property (nonatomic, readonly) TGLRenderBufferObject *lying_rbo;

+ (TGLFrameBufferObject *)createEmptyFrameBuffer;

+ (TGLFrameBufferObject *)createOnRenderBufferWithSize:(CGSize)size withInternalFormat:(GLenum)internal_format;

+ (TGLFrameBufferObject *)createOnTexture2DWithSize:(CGSize)size withInternalFormat:(GLenum)internal_format withSmooth:(BOOL)smooth;

+ (TGLFrameBufferObject *)createOnMappedTexture2DWithSize:(CGSize)size withInternalFormat:(GLenum)internal_format withSmooth:(BOOL)smooth;

+ (TGLFrameBufferObject *)createOnEAGLStorage:(EAGLContext *)context withLayer:(CAEAGLLayer *)layer;

+ (void)discardColor;

- (void)attachDepthBufferOnRenderbuffer16;
- (void)attachDepthBufferOnRenderbuffer24;

@end

