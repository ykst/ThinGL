// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import <Foundation/Foundation.h>

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#else
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#endif

@interface TGLProgram : NSObject 
{
    NSMutableArray  *attributes;
    GLuint          program,
	vertShader, 
	fragShader;	
}

@property(readwrite, nonatomic) BOOL initialized;
+ (void)unuse;
+ (TGLProgram *)createProgramWithVS:(NSString *)vs withFS:(NSString *)fs withAttributes:(NSDictionary *)attrs withUniforms:(NSDictionary *)uniforms;

- (id)initWithVertexShaderString:(NSString *)vShaderString 
            fragmentShaderString:(NSString *)fShaderString;
- (id)initWithVertexShaderString:(NSString *)vShaderString 
          fragmentShaderFilename:(NSString *)fShaderFilename;
- (id)initWithVertexShaderFilename:(NSString *)vShaderFilename 
            fragmentShaderFilename:(NSString *)fShaderFilename;
- (void)addAttribute:(NSString *)attributeName;
- (GLuint)attributeIndex:(NSString *)attributeName;
- (GLuint)uniformIndex:(NSString *)uniformName;
- (BOOL)link;
- (void)use;
- (void)useBlock:(void (^)(void))block;
- (NSString *)vertexShaderLog;
- (NSString *)fragmentShaderLog;
- (NSString *)programLog;
- (void)validate;

// +++
- (void)dumpCompileLog;
@end

