// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import "TGLRenderBufferObject.h"

@interface TGLRenderBufferObject()
@property (nonatomic, readwrite) GLuint name;
@property (nonatomic, readwrite) GLenum internal_format;
@property (nonatomic, readwrite) CGSize size;
@end

@implementation TGLRenderBufferObject

+ (TGLRenderBufferObject *)createRenderBufferObject
{
    TGLRenderBufferObject *obj = [[TGLRenderBufferObject alloc] init];

    GLuint name = 0;
    glGenRenderbuffers(1, &name);GLASSERT;
    NSASSERT(name > 0);

    obj.name = name;

    [obj bind];
    [[obj class] unbind];

    return obj;
}

+ (TGLRenderBufferObject *)createWithSize:(CGSize)size withInternalFormat:(GLenum)internal_format
{
    NSASSERT(size.width > 0);
    NSASSERT(size.height > 0);

    TGLRenderBufferObject *obj = [TGLRenderBufferObject createRenderBufferObject];

    [obj bind];

    glRenderbufferStorage(GL_RENDERBUFFER, internal_format, size.width, size.height);GLASSERT;

    [[obj class] unbind];

    obj.size = size;
    obj.internal_format = internal_format;

    return obj;
}

+ (TGLRenderBufferObject *)createWithEAGLContext:(EAGLContext *)context withLayer:(CAEAGLLayer *)layer
{
    TGLRenderBufferObject *obj = [TGLRenderBufferObject createRenderBufferObject];

    [obj bind];
    
    [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];GLASSERT;

    GLint width = 0, height = 0, internal_format = 0;

    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width);GLASSERT;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height);GLASSERT;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_INTERNAL_FORMAT,  &   internal_format);GLASSERT;

    [[obj class] unbind];

    obj.size = CGSizeMake(width, height);
    obj.internal_format = internal_format;

    return obj;
}

- (void)bindBlock:(void (^)())block
{
    [self bind];
    block();
    [[self class] unbind];
}

- (void)bind
{
    glBindRenderbuffer(GL_RENDERBUFFER, _name);GLASSERT;
}

+ (void)unbind
{
    glBindRenderbuffer(GL_RENDERBUFFER, 0);GLASSERT;
}

- (void)dealloc
{
    if (_name) {
        glDeleteRenderbuffers(1, &_name);
        _name = 0;
    }
}
@end

