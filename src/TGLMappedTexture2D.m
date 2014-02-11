// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import "NSObject+SimpleArchiver.h"
#import "TGLMappedTexture2D.h"
#import "TGLDevice.h"

@interface TGLMappedTexture2D() {
    @protected
    CVPixelBufferRef _pixel_buffer;
    CVOpenGLESTextureRef _texture_ref;
    CVOpenGLESTextureCacheRef _texture_cache;
    BOOL _is_planar;
    NSUInteger _plane_index;
}
@property (nonatomic, readwrite) GLuint name;
@property (nonatomic, readwrite) GLenum internal_format;
@property (nonatomic, readwrite) size_t num_bytes;
@property (nonatomic, readwrite) size_t bytes_per_row;
@property (nonatomic, readwrite) BOOL smooth;
@property (nonatomic, readwrite) BOOL repeat;
@property (nonatomic, readwrite) NSData *buffer_to_save;
@end

@implementation TGLMappedTexture2D

// 単に共通処理を抜いただけなので副作用がマッハ
- (void)_setupTexturePostProcess:(BOOL)smooth withRepeat:(BOOL)repeat
{
    _name = CVOpenGLESTextureGetName(_texture_ref);
    _smooth = smooth;

    GLenum target = CVOpenGLESTextureGetTarget(_texture_ref);

    // if texture target was not 2D, users must be inconsistent.
    NSASSERT(target == GL_TEXTURE_2D);

    glBindTexture(GL_TEXTURE_2D, _name);

    GLenum filter = smooth ? GL_LINEAR : GL_NEAREST;
    GLenum outside = repeat ? GL_REPEAT : GL_CLAMP_TO_EDGE;

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filter);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, outside);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, outside);

    glBindTexture(GL_TEXTURE_2D, 0);
}

static BOOL __get_byte_format(GLenum *in_out_internal_format,
                              GLenum *out_format,
                              GLenum *out_gl_type,
                              OSType *out_pixel_format)
{
    OSType pixel_format = kCVPixelFormatType_32BGRA;
    GLenum internal_format = *in_out_internal_format;
    GLenum input_gl_format = GL_RGBA;
    GLenum input_gl_type = GL_UNSIGNED_BYTE;

    // TODO: support planar format?
    switch (internal_format) {
    case GL_RGBA:
        pixel_format = kCVPixelFormatType_32BGRA;
        input_gl_format = GL_RGBA;
        internal_format = GL_RGBA;
        input_gl_type = GL_UNSIGNED_BYTE;
        break;
    case GL_LUMINANCE:
        pixel_format = kCVPixelFormatType_OneComponent8;
        input_gl_format = GL_LUMINANCE;
        internal_format = GL_LUMINANCE;
        input_gl_type = GL_UNSIGNED_BYTE;
        break;
    case GL_RGBA16F_EXT:
        // ref: http://volcore.limbic.com/2011/10/23/hdr-rendering-on-ios-ipad2iphone-4s/
        pixel_format = kCVPixelFormatType_64RGBAHalf;
        input_gl_format = GL_RGBA;
        internal_format = GL_RGBA;
        input_gl_type = GL_HALF_FLOAT_OES;
        break;
    case GL_LUMINANCE32F_EXT:
        pixel_format = kCVPixelFormatType_OneComponent32Float;
        input_gl_format = GL_LUMINANCE;
        internal_format = GL_LUMINANCE;
        input_gl_type = GL_FLOAT;
        break;
    case GL_LUMINANCE16F_EXT:
        pixel_format = kCVPixelFormatType_OneComponent16Half;
        input_gl_format = GL_LUMINANCE;
        internal_format = GL_LUMINANCE;
        input_gl_type = GL_HALF_FLOAT_OES;
        break;
    case GL_RGBA32F_EXT:
        pixel_format = kCVPixelFormatType_128RGBAFloat;
        input_gl_format = GL_RGBA;
        internal_format = GL_RGBA;
        input_gl_type = GL_FLOAT;
        break;
    default: return NO;
    }

    *in_out_internal_format = internal_format;
    *out_gl_type = input_gl_type;
    *out_format = input_gl_format;
    *out_pixel_format = pixel_format;

    return YES;
}

- (void)writeData:(NSData *)data
{
    [self useWritable:^(void *buf) {
        memcpy(buf, data.bytes, MIN(_num_bytes, data.length));
    }];
}

+ (CGSize)getAlignedSizeFromImage:(UIImage *)image
{
    CGImageRef imageRef = [image CGImage];
    NSUInteger width = (CGImageGetWidth(imageRef) >> 4) << 4;
    NSUInteger height = CGImageGetHeight(imageRef);

    return CGSizeMake(width, height);
}

+ (NSData *)getRGBAsFromImage:(UIImage *)image
{
    // First get the image into your data buffer
    CGImageRef imageRef = [image CGImage];
    CGSize aligned_size = [TGLMappedTexture2D getAlignedSizeFromImage:image];
    NSUInteger width = aligned_size.width;
    NSUInteger height = aligned_size.height;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    size_t byte_length = height * width * 4;
    NSMutableData *data = [NSMutableData dataWithLength:byte_length];
    unsigned char *rawData = data.mutableBytes;
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;

    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);

    CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    return data;
}

+ (TGLMappedTexture2D *)createFromUIImage:(UIImage *)image withSmooth:(BOOL)smooth
{
    NSASSERT(image);

    // to avoid corruption, width must be aligned to 16
    TGLMappedTexture2D *obj = [TGLMappedTexture2D createWithSize:[TGLMappedTexture2D getAlignedSizeFromImage:image] withInternalFormat:GL_RGBA withSmooth:smooth];

    [obj writeData:[TGLMappedTexture2D getRGBAsFromImage:image]];

    return obj;
}


- (id)initWithSize:(CGSize)size withInternalFormat:(GLenum)internal_format withSmooth:(BOOL)smooth withRepeat:(BOOL)repeat
{
    self = [super init];

    if (self) {
        _texture_cache = [TGLDevice getFastTextureCacheRef];

        CVReturn err;

        // Code originally sourced from http://allmybrain.com/2011/12/08/rendering-to-a-texture-with-ios-5-texture-cache-api/
        CFDictionaryRef empty; // empty value for attr value.
        CFMutableDictionaryRef attrs;

        empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks); // our empty IOSurface properties dictionary

        attrs = CFDictionaryCreateMutable(kCFAllocatorDefault, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

        CFDictionarySetValue(attrs, kCVPixelBufferIOSurfacePropertiesKey, empty);

        OSType pixel_format = kCVPixelFormatType_32BGRA;
        GLenum input_gl_format = GL_RGBA;
        GLenum input_gl_type = GL_UNSIGNED_BYTE;

        NSASSERT(__get_byte_format(&internal_format, &input_gl_format, &input_gl_type, &pixel_format));

        err = CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, pixel_format, attrs, &_pixel_buffer);

        NSASSERT(!err);

        _num_bytes = CVPixelBufferGetDataSize(_pixel_buffer);

        NSASSERT(_num_bytes > 0);

        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                           _texture_cache,
                                                           _pixel_buffer,
                                                           NULL,
                                                           GL_TEXTURE_2D,
                                                           internal_format,
                                                           size.width,
                                                           size.height,
                                                           input_gl_format,
                                                           input_gl_type,
                                                           0,
                                                           &_texture_ref);

        NSASSERT(!err);

        CFRelease(attrs);
        CFRelease(empty);

        [self _setupTexturePostProcess:smooth withRepeat:repeat];

        _size = size;
        _repeat = repeat;
        _bytes_per_row = CVPixelBufferGetBytesPerRow(_pixel_buffer);
        _internal_format = internal_format;
        _is_planar = CVPixelBufferIsPlanar(_pixel_buffer);
        _plane_index = 0;
    }
    
    return self;
}

- (id)initFromImageBuffer:(CVImageBufferRef)buffer withSize:(CGSize)size withPlaneIdx:(NSInteger)plane_idx withInternalFormat:(GLenum)internal_format withSmooth:(BOOL)smooth withRepeat:(BOOL)repeat
{
    self = [super init];

    if (self) {

        if (!_texture_cache) {
            _texture_cache = [TGLDevice getFastTextureCacheRef];
        }
        _pixel_buffer = buffer;
        _num_bytes = CVPixelBufferGetDataSize(_pixel_buffer);

        CFRetain(buffer);

        CVReturn err;

        GLenum format = GL_LUMINANCE;

        switch(internal_format) {
            case GL_LUMINANCE: format = GL_LUMINANCE; break;
            case GL_LUMINANCE_ALPHA: format = GL_LUMINANCE_ALPHA; break;
            case GL_RGBA: format = GL_BGRA; break;
            default: NSASSERT(!"Unexpected buffer type"); break;
        }

        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _texture_cache, buffer, NULL, GL_TEXTURE_2D, internal_format, size.width, size.height, format, GL_UNSIGNED_BYTE, plane_idx, &_texture_ref);

        NSASSERT(!err);

        [self _setupTexturePostProcess:smooth withRepeat:repeat];

        _size = size;
        _repeat = repeat;
        _bytes_per_row = CVPixelBufferGetBytesPerRow(_pixel_buffer);
        _internal_format = internal_format;
        _is_planar = CVPixelBufferIsPlanar(_pixel_buffer);
        _plane_index = plane_idx;
    }

    return self;
}

+ (TGLMappedTexture2D *)createFromImageBuffer:(CVImageBufferRef)buffer withSize:(CGSize)size withPlaneIdx:(NSInteger)plane_idx withInternalFormat:(GLenum)internal_format withSmooth:(BOOL)smooth
{
    NSASSERT(size.width > 0 && size.height > 0);

    __block TGLMappedTexture2D *obj;
    [TGLDevice runOnProcessQueueSync:^(EAGLContext *_) {
        obj = [[TGLMappedTexture2D alloc] initFromImageBuffer:buffer withSize:size withPlaneIdx:plane_idx withInternalFormat:internal_format withSmooth:smooth withRepeat:NO];
    }];
    return obj;
}

+ (TGLMappedTexture2D *)createWithSize:(CGSize)size withInternalFormat:(GLenum)internal_format withSmooth:(BOOL)smooth
{
    return [TGLMappedTexture2D createWithSize:size withInternalFormat:internal_format withSmooth:smooth withRepeat:NO];
}

+ (TGLMappedTexture2D *)createWithSize:(CGSize)size withInternalFormat:(GLenum)internal_format withSmooth:(BOOL)smooth withRepeat:(BOOL)repeat
{
    NSASSERT(size.width > 0 && size.height > 0);

    __block TGLMappedTexture2D *obj;
    [TGLDevice runOnProcessQueueSync:^(EAGLContext *_) {
        obj = [[TGLMappedTexture2D alloc] initWithSize:size withInternalFormat:internal_format withSmooth:smooth withRepeat:repeat];
    }];
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
    glBindTexture(GL_TEXTURE_2D, _name);GLASSERT;
}

+ (void)unbind
{
    glBindTexture(GL_TEXTURE_2D, 0);GLASSERT;
}

- (void)randomize
{
    [self useWritable:^(void *buf) {
        uint32_t *buf32 = buf;
        const int cnt = _num_bytes / 4;
        for (int i = 0; i < cnt; ++i) {
            *buf32 = arc4random();
            ++buf32;
        }
    }];
}

- (void)dealloc
{
    [TGLDevice runOnProcessQueueSync:^(EAGLContext *_) {
        //glFinish();
        if (_texture_ref) {
            CFRelease(_texture_ref);
        }

        if (_pixel_buffer) {
            CVPixelBufferUnlockBaseAddress(_pixel_buffer, 0);
            CVPixelBufferRelease(_pixel_buffer);
        }
    }];
}

- (void *)_lockWithFlag:(CVOptionFlags)flag
{
    NSASSERT(CVPixelBufferLockBaseAddress(_pixel_buffer, flag) == kCVReturnSuccess);

    void *buf = NULL;

    if (_is_planar) {
        buf = CVPixelBufferGetBaseAddressOfPlane(_pixel_buffer, _plane_index);
    } else {
        buf = CVPixelBufferGetBaseAddress(_pixel_buffer);
    }

    NSASSERT(buf != NULL);

    return buf;
}

- (void)_unlockWithFlag:(CVOptionFlags)flag
{
    NSASSERT(CVPixelBufferUnlockBaseAddress(_pixel_buffer, flag) == kCVReturnSuccess);
}

- (void)_useWithFlag:(CVOptionFlags)flag withBlock:(void (^)(void *))block
{
    block([self _lockWithFlag:flag]);

    [self _unlockWithFlag:flag];
}

- (void)useReadOnly:(void (^)(const void *))block
{
    [self _useWithFlag:kCVPixelBufferLock_ReadOnly withBlock:(void (^)(void *))block];
}

- (void)useWritable:(void (^)(void *))block
{
    [self _useWithFlag:0 withBlock:block];
}

- (void *)lockWritable
{
    return [self _lockWithFlag:0];
}

- (void)unlockWritable
{
    [self _unlockWithFlag:0];
}

- (const void *)lockReadonly
{
    // NOTE:
    // kCVPixelBufferLock_ReadOnly seems to take a little time to fill out memory.
    // This behaviour is not expected and there is no way to block its completion.
    // So we avoid it and just rely on static constant qualifier. figures.

    //return [self _lockWithFlag:kCVPixelBufferLock_ReadOnly];

    return [self _lockWithFlag:0];
}

- (void)unlockReadonly
{
    //[self _unlockWithFlag:kCVPixelBufferLock_ReadOnly];
    [self _unlockWithFlag:0];
}

// FIXME: should be defined in super class
- (void)setUniform:(GLint)uniform_idx onUnit:(GLint)unit_idx
{
    glActiveTexture(GL_TEXTURE0 + unit_idx);GLASSERT;
    [self bind];
    glUniform1i(uniform_idx, unit_idx);GLASSERT;
}

- (void)attachColorFB
{
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _name, 0);GLASSERT;
}

- (BOOL)save:(NSString *)name
{
    _buffer_to_save = [NSData dataWithBytes:[self lockReadonly] length:_num_bytes];

    [self unlockReadonly];

    BOOL ret =  [self simpleArchiveForKey:name];

    NSASSERT(ret);

    _buffer_to_save = nil;

    return ret;
}

+ (TGLMappedTexture2D *)load:(NSString *)name
{
    TGLMappedTexture2D *result = nil;

    @autoreleasepool {
        TGLMappedTexture2D *dummy_obj = [TGLMappedTexture2D simpleUnarchiveForKey:name];

        NSASSERT(dummy_obj);
        
        result = [TGLMappedTexture2D createWithSize:dummy_obj.size withInternalFormat:dummy_obj.internal_format withSmooth:dummy_obj.smooth];

        [result writeData:dummy_obj.buffer_to_save];
    }

    return result;
}
@end

