// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import <Foundation/Foundation.h>
#import "TGLDevice.h"
#import "TGLBindable.h"

struct gl_vbo_object_command {
    const GLint attribute;
    const GLuint counts;
    const GLenum type;
    const GLuint elems;
    const GLuint stride;
    const GLboolean normalize;
    const void *ptr;
};

@interface TGLVertexBufferObject : NSObject<TGLBindable>

// NOTE: the last element of commands must be 0 cleared concrete object
//       set auto_offset to no on interleaved input for which a buffer contains all arrangement.
+ (TGLVertexBufferObject *)createVBOWithUsage:(GLenum)usage withAutoOffset:(BOOL)auto_offset withCommand:(struct gl_vbo_object_command *)commands;

- (void)subDataOfAttribute:(GLint)attribute withPointer:(void const * const)ptr withElems:(GLuint)elems;
- (void)invalidate;

@end

