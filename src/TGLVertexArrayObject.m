// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import "TGLVertexArrayObject.h"
#import "TGLDevice.h"

@interface TGLVertexArrayObject()
@property(nonatomic, readwrite) GLuint name;
@end

@implementation TGLVertexArrayObject

+ (TGLVertexArrayObject *)create
{
    TGLVertexArrayObject *obj = [[TGLVertexArrayObject alloc] init];

    GLuint name = 0;

    glGenVertexArraysOES(1, &name);GLASSERT;

    NSASSERT(name > 0);

    obj.name = name;

    return obj;
}

- (void)bind
{
    glBindVertexArrayOES(_name);GLASSERT;
}

+ (void)unbind
{
    glBindVertexArrayOES(0);GLASSERT;
}

// FIXME: DRY.. should be implemented by super class
- (void)bindBlock:(void (^)())block
{
    [self bind];
    block();
    [[self class] unbind];
}

-(void)dealloc
{
    if (_name > 0) {
        glDeleteVertexArraysOES(1, &_name);
        _name = 0;
    }
}
@end

