// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import "TGLVertexBufferObject.h"
#import "TGLDevice.h"

@interface TGLVertexBufferObject()
@property (nonatomic, readwrite) GLuint name;
@property (nonatomic, readwrite) NSMutableArray *commands;
@property (nonatomic, readwrite) NSMutableArray *sizes;
@property (nonatomic, readwrite) GLenum usage;
@property (nonatomic, readwrite) GLenum auto_offset;
@property (nonatomic, readwrite) GLsizei total_size;
@end

@implementation TGLVertexBufferObject

static inline GLsizei __get_gl_type_size(GLenum type) {
    GLsizei type_size = 1;

    // what the fucking hell
    switch(type) {
        case GL_FLOAT: type_size = sizeof(GLfloat); break;
        case GL_SHORT: type_size = sizeof(GLshort); break;
        case GL_UNSIGNED_SHORT: type_size = sizeof(GLshort); break;
        case GL_HALF_FLOAT_OES: type_size = sizeof(GLhalf); break;
        case GL_UNSIGNED_BYTE: type_size = sizeof(GLubyte); break;
        case GL_BYTE: type_size = sizeof(GLbyte); break;
        default: ASSERT(!"Unhandled GL type", return 0);
    }

    return  type_size;
}

+ (TGLVertexBufferObject *)createVBOWithUsage:(GLenum)usage withAutoOffset:(BOOL)auto_offset withCommand:(struct gl_vbo_object_command *)commands
{
    TGLVertexBufferObject *obj = [[TGLVertexBufferObject alloc] init];

    GLuint name = 0;
    glGenBuffers(1, &name);GLASSERT;
    NSASSERT(name > 0);

    obj.name = name;
    obj.usage = usage;
    obj.auto_offset = auto_offset;

    [obj bind];

    GLsizei total_size = 0;

    for (struct gl_vbo_object_command *command = commands; command && command->counts > 0; ++command) {
        GLsizei type_size = __get_gl_type_size(command->type);
        NSASSERT(type_size > 0);

        [obj.commands addObject:[NSValue valueWithBytes:command objCType:@encode(struct gl_vbo_object_command)]];

        GLsizei attribute_size = command->counts * type_size * command->elems;
        [obj.sizes addObject:@(attribute_size)];
        total_size += attribute_size;
    }

    glBufferData(GL_ARRAY_BUFFER, total_size, NULL, usage);GLASSERT;

    void *offset = 0;
    int const command_count = (int)[obj.commands count];
    for (int i = 0; i < command_count; ++i) {
        struct gl_vbo_object_command *command = &commands[i];

        // goes to VAO
        glEnableVertexAttribArray(command->attribute);GLASSERT;

        // goes to VAO
        glVertexAttribPointer(
                              command->attribute,
                              command->counts,
                              command->type,
                              command->normalize,
                              command->stride,
                              GLBUFFER_OFFSET(offset));GLASSERT;

        if (command->ptr != NULL) {
            glBufferSubData(GL_ARRAY_BUFFER, (GLsizei)offset, [obj.sizes[i] unsignedIntValue], command->ptr);GLASSERT;
        }

        if (auto_offset) {
            offset += [obj.sizes[i] unsignedIntValue];
        }
    }

    [[obj class] unbind];

    obj.total_size = total_size;

    return obj;
}

- (void)subDataOfAttribute:(GLint)attribute withPointer:(void const * const)ptr withElems:(GLuint)elems
{
    BOOL found = NO;
    struct gl_vbo_object_command command = {};

    int idx = 0;
    int offset = 0;
    for (NSValue *v in _commands) {
        [v getValue:&command];
        if (command.attribute == attribute) {
            found = YES;
            break;
        }
        if (_auto_offset) {
            offset += [_sizes[idx] unsignedIntValue];
        }
        ++idx;
    }

    NSASSERT(found);
    NSASSERT(elems <= command.elems);

    [self bind];

    GLsizei update_size = __get_gl_type_size(command.type) * elems * command.counts;

    NSASSERT(update_size > 0);

    if ([_commands count] == 1) {
        glBufferData(GL_ARRAY_BUFFER, update_size, ptr, _usage);GLASSERT;
    } else {
        glBufferSubData(GL_ARRAY_BUFFER, offset, update_size, ptr);GLASSERT;
    }

    [[self class] unbind];
}

- (void)invalidate
{
    [self bind];
    glBufferData(GL_ARRAY_BUFFER, _total_size, NULL, _usage);GLASSERT;
    //[[self class] unbind];
}

- (id)init
{
    self = [super init];
    if (self) {
        _commands = [NSMutableArray array];
        _sizes = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc
{
    // TODO: thread safe..?
    if (_name > 0) {
        glDeleteBuffers(1, &_name);
        _name = 0;
    }
}

- (void)bind
{
    glBindBuffer(GL_ARRAY_BUFFER, _name);GLASSERT;
}

+ (void)unbind
{
    glBindBuffer(GL_ARRAY_BUFFER, 0);GLASSERT;
}

- (void)bindBlock:(void (^)())block
{
    [self bind];
    block();
    [[self class] unbind];
}

@end

