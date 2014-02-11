// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php


#import "TGLProgram.h"
// START:typedefs
#pragma mark Function Pointer Definitions
typedef void (*GLInfoFunction)(GLuint program, 
                               GLenum pname, 
                               GLint* params);
typedef void (*GLLogFunction) (GLuint program, 
                               GLsizei bufsize, 
                               GLsizei* length, 
                               GLchar* infolog);
// END:typedefs
#pragma mark -
#pragma mark Private Extension Method Declaration
// START:extension
@interface TGLProgram()

- (BOOL)compileShader:(GLuint *)shader 
                 type:(GLenum)type 
               string:(NSString *)shaderString;
- (NSString *)logForOpenGLObject:(GLuint)object 
                    infoCallback:(GLInfoFunction)infoFunc 
                         logFunc:(GLLogFunction)logFunc;
@end
// END:extension
#pragma mark -

@implementation TGLProgram
// START:init

@synthesize initialized = _initialized;

- (id)initWithVertexShaderString:(NSString *)vShaderString 
            fragmentShaderString:(NSString *)fShaderString;
{
    if ((self = [super init]))
    {
        _initialized = NO;
        
        attributes = [[NSMutableArray alloc] init];

        program = glCreateProgram();
        
        if (![self compileShader:&vertShader 
                            type:GL_VERTEX_SHADER 
                          string:vShaderString])
            NSLog(@"Failed to compile vertex shader");
        
        // Create and compile fragment shader
        if (![self compileShader:&fragShader 
                            type:GL_FRAGMENT_SHADER 
                          string:fShaderString])
            NSLog(@"Failed to compile fragment shader");
        
        glAttachShader(program, vertShader);
        glAttachShader(program, fragShader);
    }
    
    return self;
}

- (id)initWithVertexShaderString:(NSString *)vShaderString 
          fragmentShaderFilename:(NSString *)fShaderFilename;
{
    NSString *fragShaderPathname = [[NSBundle mainBundle] pathForResource:fShaderFilename ofType:@"fsh"];
    NSString *fragmentShaderString = [NSString stringWithContentsOfFile:fragShaderPathname encoding:NSUTF8StringEncoding error:nil];
    
    if ((self = [self initWithVertexShaderString:vShaderString fragmentShaderString:fragmentShaderString])) 
    {
    }
    
    return self;
}

- (id)initWithVertexShaderFilename:(NSString *)vShaderFilename 
            fragmentShaderFilename:(NSString *)fShaderFilename;
{
    NSString *vertShaderPathname = [[NSBundle mainBundle] pathForResource:vShaderFilename ofType:@"vsh"];
    NSString *vertexShaderString = [NSString stringWithContentsOfFile:vertShaderPathname encoding:NSUTF8StringEncoding error:nil];

    NSString *fragShaderPathname = [[NSBundle mainBundle] pathForResource:fShaderFilename ofType:@"fsh"];
    NSString *fragmentShaderString = [NSString stringWithContentsOfFile:fragShaderPathname encoding:NSUTF8StringEncoding error:nil];
    
    if ((self = [self initWithVertexShaderString:vertexShaderString fragmentShaderString:fragmentShaderString])) 
    {
    }
    
    return self;
}
// END:init
// START:compile
- (BOOL)compileShader:(GLuint *)shader 
                 type:(GLenum)type 
               string:(NSString *)shaderString
{
    GLint status;
    const GLchar *source;
    
    source = 
      (GLchar *)[shaderString UTF8String];
    if (!source)
    {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);

	if (status != GL_TRUE)
	{
		GLint logLength;
		glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
		if (logLength > 0)
		{
			GLchar *log = (GLchar *)malloc(logLength);
			glGetShaderInfoLog(*shader, logLength, &logLength, log);
			NSLog(@"Shader compile log:\n%s", log);
			free(log);
		}
	}	
	
    return status == GL_TRUE;
}
// END:compile
#pragma mark -
// START:addattribute
- (void)addAttribute:(NSString *)attributeName
{
    if (![attributes containsObject:attributeName])
    {
        [attributes addObject:attributeName];
        glBindAttribLocation(program, 
                             (GLuint)[attributes indexOfObject:attributeName],
                             [attributeName UTF8String]);
    }
}
// END:addattribute
// START:indexmethods
- (GLuint)attributeIndex:(NSString *)attributeName
{
    return (GLuint)[attributes indexOfObject:attributeName];
}
- (GLuint)uniformIndex:(NSString *)uniformName
{
    return glGetUniformLocation(program, [uniformName UTF8String]);
}
// END:indexmethods
#pragma mark -
// START:link
- (BOOL)link
{
    GLint status;
    
    glLinkProgram(program);
    
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE)
        return NO;
    
    if (vertShader)
    {
        glDetachShader(program, vertShader);
        glDeleteShader(vertShader);
        vertShader = 0;
    }
    if (fragShader)
    {
        glDetachShader(program, fragShader);
        glDeleteShader(fragShader);
        fragShader = 0;
    }
    
    self.initialized = YES;
    return YES;
}
// END:link
// START:use
- (void)use
{
    glUseProgram(program);
}

- (void)useBlock:(void (^)(void))block
{
    [self use];
    block();
    [[self class] unuse];
}

+ (void)unuse
{
    glUseProgram(0);
}
// END:use
#pragma mark -
// START:privatelog
- (NSString *)logForOpenGLObject:(GLuint)object 
                    infoCallback:(GLInfoFunction)infoFunc 
                         logFunc:(GLLogFunction)logFunc
{
    GLint logLength = 0, charsWritten = 0;
    
    infoFunc(object, GL_INFO_LOG_LENGTH, &logLength);    
    if (logLength < 1)
        return nil;
    
    char *logBytes = malloc(logLength);
    logFunc(object, logLength, &charsWritten, logBytes);
    NSString *log = [[NSString alloc] initWithBytes:logBytes 
                                              length:logLength 
                                            encoding:NSUTF8StringEncoding];
    free(logBytes);
    return log;
}
// END:privatelog
// START:log
- (NSString *)vertexShaderLog
{
    return [self logForOpenGLObject:vertShader 
                       infoCallback:(GLInfoFunction)&glGetProgramiv 
                            logFunc:(GLLogFunction)&glGetProgramInfoLog];
    
}
- (NSString *)fragmentShaderLog
{
    return [self logForOpenGLObject:fragShader 
                       infoCallback:(GLInfoFunction)&glGetProgramiv 
                            logFunc:(GLLogFunction)&glGetProgramInfoLog];
}
- (NSString *)programLog
{
    return [self logForOpenGLObject:program 
                       infoCallback:(GLInfoFunction)&glGetProgramiv 
                            logFunc:(GLLogFunction)&glGetProgramInfoLog];
}
// END:log

- (void)validate;
{
	GLint logLength;
	
	glValidateProgram(program);
	glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0)
	{
		GLchar *log = (GLchar *)malloc(logLength);
		glGetProgramInfoLog(program, logLength, &logLength, log);
		NSLog(@"Program validate log:\n%s", log);
		free(log);
	}	
}

#pragma mark -
// START:dealloc
- (void)dealloc
{
    if (vertShader)
        glDeleteShader(vertShader);
        
    if (fragShader)
        glDeleteShader(fragShader);
    
    if (program)
        glDeleteProgram(program);
       
}
// END:dealloc

- (void)dumpCompileLog
{
    NSString *progLog = [self programLog];
    NSLog(@"Program link log: %@", progLog);
    NSString *fragLog = [self fragmentShaderLog];
    NSLog(@"Fragment shader compile log: %@", fragLog);
    NSString *vertLog = [self vertexShaderLog];
    NSLog(@"Vertex shader compile log: %@", vertLog);
}

+ (TGLProgram *)createProgramWithVS:(NSString *)vs withFS:(NSString *)fs withAttributes:(NSDictionary *)attrs withUniforms:(NSDictionary *)uniforms
{
    TGLProgram *prog = [[TGLProgram alloc] initWithVertexShaderString:vs fragmentShaderString:fs];

    if (!prog) return nil;

	[attrs enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		[prog addAttribute:key];
	}];

    if(![prog link]) {
        [prog dumpCompileLog];
        NSLog(@"shader compile failed");
        return nil;
    }

    [attrs enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        GLint index = [prog attributeIndex:key];
        if (index < 0) {
            NSLog(@"missing attribute: %@", key);
        }
        NSValue *ptr = obj;
        *(GLint *)[ptr pointerValue] = index;
    }];

    [uniforms enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        GLint index = [prog uniformIndex:key];
        if (index < 0) {
            NSLog(@"missing uniform: %@", key);
        }
        NSValue *ptr = obj;
        *(GLint *)[ptr pointerValue] = index;
    }];

    return prog;
}

@end

