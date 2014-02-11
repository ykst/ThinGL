// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import "TGLFrameBufferObject.h"
#import "TGLRenderBufferObject.h"
#import "TGLTexture2D.h"
#import "TGLMappedTexture2D.h"

@interface TGLFrameBufferObject() {

}

@property (nonatomic, readwrite) GLuint name;
@property (nonatomic, readwrite) NSMutableArray *backings;
@property (nonatomic, readwrite) CGSize size;
@property (nonatomic, readwrite) TGLMappedTexture2D *mapped_texture;
@property (nonatomic, readwrite) TGLRenderBufferObject *lying_rbo;

@end

@implementation TGLFrameBufferObject

+ (TGLFrameBufferObject *)createEmptyFrameBuffer
{
    TGLFrameBufferObject *obj = [[TGLFrameBufferObject alloc] init];

    GLuint name = 0;
    glGenFramebuffers(1, &name);GLASSERT;

    NSASSERT(name > 0);

    obj.name = name;

    [obj bind];
    [[obj class] unbind];

    return obj;
}

+ (TGLFrameBufferObject *)createOnRenderBufferWithSize:(CGSize)size withInternalFormat:(GLenum)internal_format
{
    TGLFrameBufferObject *obj = [TGLFrameBufferObject createEmptyFrameBuffer];

    TGLRenderBufferObject *color_rbo = [TGLRenderBufferObject createWithSize:size withInternalFormat:internal_format];

    [obj bind];

    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, color_rbo.name);GLASSERT;

    NSASSERT(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);

    [[obj class] unbind];

    [obj.backings addObject:color_rbo];

    obj.lying_rbo = color_rbo;

    obj.size = size;

    return obj;
}

+ (TGLFrameBufferObject *)createOnEAGLStorage:(EAGLContext *)context withLayer:(CAEAGLLayer *)layer
{
    TGLFrameBufferObject *obj = [TGLFrameBufferObject createEmptyFrameBuffer];
    
    TGLRenderBufferObject *rbo = [TGLRenderBufferObject createWithEAGLContext:context withLayer:layer];

    [obj attachRenderbuffer:rbo];

    return obj;
}

- (void)attachRenderbuffer:(TGLRenderBufferObject *)rbo
{
    [self bind];

    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, rbo.name);GLASSERT;

    NSASSERT(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);

    [[self class] unbind];

    [self.backings addObject:rbo];
    self.lying_rbo = rbo;

    self.size = rbo.size;
}

+ (TGLFrameBufferObject *)createOnTexture2DWithSize:(CGSize)size withInternalFormat:(GLenum)internal_format withSmooth:(BOOL)smooth
{
    TGLFrameBufferObject *obj = [TGLFrameBufferObject createEmptyFrameBuffer];

    TGLTexture2D *tex = [TGLTexture2D createWithSize:size withInternalFormat:internal_format withSmooth:smooth];

    [obj bind];

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex.name, 0);

    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);

    NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete filter FBO: %d", status);

    [[obj class] unbind];

    [obj.backings addObject:tex];

    obj.size = size;

    return obj;
}

+ (TGLFrameBufferObject *)createOnMappedTexture2DWithSize:(CGSize)size withInternalFormat:(GLenum)internal_format withSmooth:(BOOL)smooth
{
    TGLFrameBufferObject *obj = [TGLFrameBufferObject createEmptyFrameBuffer];

    TGLMappedTexture2D *tex = [TGLMappedTexture2D createWithSize:size withInternalFormat:internal_format withSmooth:smooth];

    [obj bind];

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex.name, 0);

    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);

    NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete filter FBO: %d", status);

    [[obj class] unbind];

    [obj.backings addObject:tex];

    obj.size = size;
    obj.mapped_texture = tex;
    
    return obj;
}

- (id)init
{
    self = [super init];
    if (self) {
        _backings = [NSMutableArray array];
    }
    return self;
}

- (void)bind
{
    glBindFramebuffer(GL_FRAMEBUFFER, _name);GLASSERT;
}

+ (void)unbind
{
    glBindFramebuffer(GL_FRAMEBUFFER, 0);GLASSERT;
}

- (void)_attachDepthBuffer:(GLenum)attachment
{
    TGLRenderBufferObject *depth_rbo = [TGLRenderBufferObject createWithSize:_size withInternalFormat:attachment];

    [_backings addObject:depth_rbo];

    [self bind];

    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depth_rbo.name);GLASSERT;

    NSASSERT(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);

    [[self class] unbind];
}

- (void)attachDepthBufferOnRenderbuffer16
{
    [self _attachDepthBuffer:GL_DEPTH_COMPONENT16];
}

- (void)attachDepthBufferOnRenderbuffer24
{
    [self _attachDepthBuffer:GL_DEPTH_COMPONENT24_OES];
}

- (void)dealloc
{
    if (_name > 0) {
        glDeleteFramebuffers(1, &_name);
        _name = 0;
    }
}

- (void)bindBlock:(void (^)())block
{
    [self bind];
    block();
    [[self class] unbind];
}

+ (void)discardColor
{
    glDiscardFramebufferEXT(GL_FRAMEBUFFER,1,(GLenum []){GL_COLOR_ATTACHMENT0});
}
@end

