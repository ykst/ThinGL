// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import "TGLTexture2D.h"
#import "TGLDevice.h"

@interface TGLTexture2D()
@property (nonatomic, readwrite) GLuint name;
@property (nonatomic, readwrite) CGSize size;
@end

@implementation TGLTexture2D

+ (TGLTexture2D *)createWithSize:(CGSize)size withInternalFormat:(GLenum)internal_format withSmooth:(BOOL)smooth
{
    TGLTexture2D *obj = [[TGLTexture2D alloc] init];

    GLuint name = 0;

    glGenTextures(1, &name);GLASSERT;
    NSASSERT(name > 0);
    obj.name = name;

    [obj bind];

    GLenum filter = smooth ? GL_LINEAR : GL_NEAREST;
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filter);GLASSERT;
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filter);GLASSERT;
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);GLASSERT;
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);GLASSERT;

    GLenum input_gl_format = GL_RGBA;
    GLenum input_gl_type = GL_UNSIGNED_BYTE;
    // TODO: support planar format?
    switch (internal_format) {
        case GL_RGBA:
            input_gl_format = internal_format;
            input_gl_type = GL_UNSIGNED_BYTE;
            break;
        case GL_LUMINANCE:
            input_gl_format = internal_format;
            input_gl_type = GL_UNSIGNED_BYTE;
            break;
        case GL_RGBA16F_EXT:
            input_gl_format = GL_RGBA;
            internal_format = GL_RGBA;
            input_gl_type = GL_HALF_FLOAT_OES;
            break;
        default: NSASSERT(!"Incompatible format for pixel buffer"); break;
    }

    glTexImage2D(GL_TEXTURE_2D, 0, internal_format, size.width, size.height, 0, input_gl_format, input_gl_type, 0);GLASSERT;

    [[obj class] unbind];

    obj.size = size;

    return obj;
}

- (void)bind
{
    glBindTexture(GL_TEXTURE_2D, _name);GLASSERT;
}

+ (void)unbind
{
    glBindTexture(GL_TEXTURE_2D, 0);GLASSERT;
}

- (void)dealloc
{
    if (_name > 0) {
        glDeleteTextures(1, &_name);
        _name = 0;
    }
}
@end

