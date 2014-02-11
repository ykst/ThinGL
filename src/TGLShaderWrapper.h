// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import <Foundation/Foundation.h>
#import "TGLDevice.h"
#import "TGLProgram.h"
#import "TGLVertexArrayObject.h"
#import "TGLVertexBufferObject.h"
#import "TGLFrameBufferObject.h"

#define SHADER_WRAPPER_ATTRIBUTE_PREFIX @"_attribute_"
#define SHADER_WRAPPER_UNIFORM_PREFIX @"_uniform_"

#define SHADER_VBO_FILL_TRIANGLE_STRIP (GLfloat []) {-1.0f, -1.0f, 1.0f, -1.0f, -1.0f, 1.0f, 1.0f, 1.0f}
#define SHADER_VBO_FILL_TEXTURE_TRIANGLE_STRIP (GLfloat []){ 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 1.0f, 1.0f}
#define SHADER_VBO_FILL_LINE (GLfloat []){-1.0f, 0.0f, 1.0f, 0.0f}

@interface TGLShaderWrapper : NSObject {
    @protected
    TGLProgram *_program;
    TGLVertexArrayObject *_vao;
    TGLVertexBufferObject *_vbo;
    TGLFrameBufferObject *_fbo;
}
// サブクラスがattribute_xxxまたはuniform_yyyで始まるGLintのpropertyを持つとき、
// attribute変数xxxとuniform変数yyyのインデックスをここで取得して保持する
- (void)setupShaderWithVS:(NSString *)vs withFS:(NSString *)fs;
@end

@interface GLPassthroughShaderWrapper : TGLShaderWrapper
@property (nonatomic, readwrite) GLint attribute_position;
@property (nonatomic, readwrite) GLint attribute_inputTextureCoordinate;

- (void)setupShaderWithFS:(NSString *)fs;
@end

@interface GL3x3ConvolutionShaderWrapper : TGLShaderWrapper
@property (nonatomic, readwrite) GLint attribute_position;
@property (nonatomic, readwrite) GLint attribute_inputTextureCoordinate;

- (void)setupShaderWithFS:(NSString *)fs;
@end

