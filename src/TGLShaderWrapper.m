// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import "TGLShaderWrapper.h"
#import <objc/runtime.h>

@implementation TGLShaderWrapper

static NSDictionary *__set_variable_dic(NSArray *array, GLint *p_idxs)
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    __block int select_idx = 0;

    for (NSString *attr in array) {
        [dic setObject:NSPOINTER(&(p_idxs[select_idx++])) forKey:attr];
    }

    return dic;
}

- (void)_feedbackVariables:(NSArray *)array withPrefix:(NSString *)prefix withIdxs:(GLint *)p_idxs
{
    __block int select_idx = 0;

    for (NSString *attr in array) {
        [self setValue:[NSNumber numberWithInt:p_idxs[select_idx++]] forKey:NSPRINTF(@"%@%@", prefix, attr)];
    }
}

- (void)setupShaderWithVS:(NSString *)vs withFS:(NSString *)fs
{
    unsigned int count;
    objc_property_t *properties = class_copyPropertyList([self class], &count);

    if (count == 0) return;

    NSMutableArray *attributes = [NSMutableArray array];
    NSMutableArray *uniforms = [NSMutableArray array];

    for (int i = 0; i < count; ++i) {
        objc_property_t property = properties[i];
        NSString *name = [NSString stringWithUTF8String:property_getName(property)];

        if ([name hasPrefix:SHADER_WRAPPER_ATTRIBUTE_PREFIX]) {
            [attributes addObject:[name substringFromIndex:10]];
        } else if ([name hasPrefix:SHADER_WRAPPER_UNIFORM_PREFIX]){
            [uniforms addObject:[name substringFromIndex:8]];
        }
/* TODO: reflection of uniform variable is in need
        NSString *type_attr = [NSSTR(property_getAttributes(property)) componentsSeparatedByString:@","][0];

        if ([type_attr hasPrefix:@"T@"] && type_attr.length > 1) {
            NSString *type_name = [type_attr substringWithRange:NSMakeRange(3, [type_attr length]-4)];
            DUMPS(type_name);
            Class type_class = NSClassFromString(type_name);
        }
*/
    }

    GLint attribute_idxs[[attributes count]];
    NSDictionary *attribute_dic = __set_variable_dic(attributes, attribute_idxs);

    GLint uniform_idxs[[uniforms count]];
    NSDictionary *uniform_dic = __set_variable_dic(uniforms, uniform_idxs);

    _program = [TGLProgram createProgramWithVS:vs
                                       withFS:fs
                               withAttributes:attribute_dic
                                 withUniforms:uniform_dic];

    [self _feedbackVariables:attributes withPrefix:SHADER_WRAPPER_ATTRIBUTE_PREFIX withIdxs:attribute_idxs];
    [self _feedbackVariables:uniforms withPrefix:SHADER_WRAPPER_UNIFORM_PREFIX withIdxs:uniform_idxs];
}
@end

@implementation GLPassthroughShaderWrapper

- (void)setupShaderWithFS:(NSString *)fs
{
    extern char passthrough_1tex_vs_glsl[];

    [self setupShaderWithVS:NSSTR(passthrough_1tex_vs_glsl) withFS:fs];

    _vao = [TGLVertexArrayObject create];
    [_vao bind];

    _vbo = [TGLVertexBufferObject createVBOWithUsage:GL_STATIC_DRAW withAutoOffset:YES withCommand:(struct gl_vbo_object_command []){
        {
            .attribute = _attribute_position,
            .counts = 2,
            .type = GL_FLOAT,
            .elems = 4,
            .ptr = (GLfloat []) {
                -1, -1,
                1, -1,
                -1, 1,
                1, 1
            }
        },
        {
            .attribute = _attribute_inputTextureCoordinate,
            .counts = 2,
            .type = GL_FLOAT,
            .elems = 4,
            .ptr = (GLfloat []){
                0.0f, 0.0f,
                1.0f, 0.0f,
                0.0f, 1.0f,
                1.0f, 1.0f,
            }
        },
        {}
    }];
    
    [[_vao class] unbind];
    
    _fbo = [TGLFrameBufferObject createEmptyFrameBuffer];
}

@end

@implementation GL3x3ConvolutionShaderWrapper

- (void)setupShaderWithFS:(NSString *)fs
{
    extern char window3x3_1tex_vs_glsl[];

    [self setupShaderWithVS:NSSTR(window3x3_1tex_vs_glsl) withFS:fs];

    _vao = [TGLVertexArrayObject create];
    [_vao bind];

    _vbo = [TGLVertexBufferObject createVBOWithUsage:GL_STATIC_DRAW withAutoOffset:YES withCommand:(struct gl_vbo_object_command []){
        {
            .attribute = _attribute_position,
            .counts = 2,
            .type = GL_FLOAT,
            .elems = 4,
            .ptr = (GLfloat []) {
                -1, -1,
                1, -1,
                -1, 1,
                1, 1
            }
        },
        {
            .attribute = _attribute_inputTextureCoordinate,
            .counts = 2,
            .type = GL_FLOAT,
            .elems = 4,
            .ptr = (GLfloat []){
                0.0f, 0.0f,
                1.0f, 0.0f,
                0.0f, 1.0f,
                1.0f, 1.0f,
            }
        },
        {}
    }];

    [[_vao class] unbind];

    _fbo = [TGLFrameBufferObject createEmptyFrameBuffer];
}

@end

