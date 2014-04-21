// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import <Foundation/Foundation.h>
#import "TGLBindable.h"

@interface TGLMappedTexture2D : NSObject<TGLBindable>

@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) GLenum internal_format;
@property (nonatomic, readonly) size_t num_bytes;
@property (nonatomic, readonly) size_t bytes_per_row;
@property (nonatomic, readonly) BOOL smooth;
@property (nonatomic, readonly) BOOL repeat;


+ (TGLMappedTexture2D *)createWithSize:(CGSize)size withInternalFormat:(GLenum)internal_format withSmooth:(BOOL)smooth;
+ (TGLMappedTexture2D *)createWithSize:(CGSize)size withInternalFormat:(GLenum)internal_format withSmooth:(BOOL)smooth withRepeat:(BOOL)repeat;

// NOTE: will not retain buffer internally
+ (TGLMappedTexture2D *)createFromImageBuffer:(CVImageBufferRef)buffer withSize:(CGSize)size withPlaneIdx:(NSInteger)plane_idx withInternalFormat:(GLenum)internal_format withSmooth:(BOOL)smooth;

+ (TGLMappedTexture2D *)createFromUIImage:(UIImage *)image withSmooth:(BOOL)smooth;

- (void)randomize;
- (void)writeData:(NSData *)data;
- (void)useReadOnly:(void (^)(const void * buf))block;
- (void)useWritable:(void (^)(void * buf))block;
- (void *)lockWritable;
- (void)unlockWritable;

- (const void *)lockReadonly;
- (void)unlockReadonly;

// TODO: should be implemented by super class
- (void)setUniform:(GLint)uniform_idx onUnit:(GLint)unit_idx;
- (void)attachColorFB;

- (BOOL)save:(NSString *)name;
- (UIImage *)toUIImage;
+ (TGLMappedTexture2D *)load:(NSString *)name;


#define TGL_USE_WRITABLE(obj, buf) for (void * buf = [(obj) lockWritable]; buf != NULL;) for (int __usewritable_dummy = 0; !__usewritable_dummy || ({ [(obj) unlockWritable]; buf = NULL; 0; }); __usewritable_dummy = 1)
#define TGL_USE_READONLY(obj, buf) for (const void *buf = [(obj) lockReadonly]; buf != NULL;) for (int __usereadonly_dummy = 0; !__usereadonly_dummy || ({ [(obj) unlockReadonly]; buf = NULL; 0; }); __usereadonly_dummy = 1)
@end

