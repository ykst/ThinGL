// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import <pthread.h>
#import "TGLDevice.h"

@interface TGLDevice() {
    dispatch_queue_t _texture_cache_queue;
}

@property (nonatomic, readwrite) EAGLContext *root_context;
@property (nonatomic, readwrite) EAGLContext *texture_cache_context;
@end

@implementation TGLDevice

+ (TGLDevice *)sharedInstance
{
    static TGLDevice * __instance;
    static dispatch_once_t __once_token;
    dispatch_once(&__once_token, ^{
        __instance = [[TGLDevice alloc] init];
    });
    return __instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.root_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:nil];
        self.texture_cache_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:self.root_context.sharegroup];
        _texture_cache_queue = dispatch_queue_create("com.monadworks.tgl.texture_cache", 0);
        dispatch_queue_set_specific(_texture_cache_queue, &_texture_cache_queue, (__bridge void *)self, NULL);
    }
    return self;
}

- (void)runTextureCache:(void (^)())block
{
    EAGLContext *prev_context = [EAGLContext currentContext];

    if (prev_context != _texture_cache_context) {
        [EAGLContext setCurrentContext:_texture_cache_context];
    }

    block();

    [TGLDevice fenceSync];

    [TGLDevice setContext:prev_context];
}

- (void)runTextureCacheQueue:(void (^)())block
{
    TGLDevice *device = [TGLDevice sharedInstance];
    if (dispatch_get_specific(&_texture_cache_queue) == (__bridge void *)self) {
        [device runTextureCache:block];
    } else {
        dispatch_sync(_texture_cache_queue, ^{
            [device runTextureCache:block];
        });
    }
}

+ (void)runTextureCacheQueueSync:(void (^)())block
{
    TGLDevice *device = [TGLDevice sharedInstance];

    [device runTextureCacheQueue:block];
}

+ (EAGLContext *)createContext
{
    TGLDevice *device = [TGLDevice sharedInstance];

    return [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:device.root_context.sharegroup];
}

+ (void)setContext:(EAGLContext *)context
{
    if ([EAGLContext currentContext] != context) {
        [EAGLContext setCurrentContext:context];
    }
}

+ (void)runPassiveContextSync:(void (^)())block
{
    EAGLContext *prev_context = [EAGLContext currentContext];

    NSASSERT(prev_context);

    block();

    [TGLDevice fenceSync];

    [TGLDevice setContext:prev_context];
}

+ (void)runMainThreadSync:(void (^)())block
{
    TGLDevice *device = [TGLDevice sharedInstance];

    if ([NSThread isMainThread]) {
        [device runMain:block];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [device runMain:block];
        });
    }
}

+ (EAGLContext *)currentContext
{
    return [EAGLContext currentContext];
}

+ (EAGLContext *)setNewContext
{
    EAGLContext *context = [TGLDevice createContext];
    [TGLDevice setContext:context];
    
    return context;
}

- (void)runMain:(void (^)())block
{
    EAGLContext *prev_context = [EAGLContext currentContext];

    if (prev_context != self.root_context) {
        [EAGLContext setCurrentContext:self.root_context];
    }

    block();

    [TGLDevice fenceSync];

    [TGLDevice setContext:prev_context];
}

+ (void)useFastTextureCacheRef:(void (^)(CVOpenGLESTextureCacheRef))block
{
    static CVOpenGLESTextureCacheRef __ref = NULL;
    static dispatch_once_t __once_token;

    dispatch_once(&__once_token, ^{
        TGLDevice *device = [TGLDevice sharedInstance];

        [TGLDevice runTextureCacheQueueSync:^{
#ifdef DEBUG
            CVReturn err =
#endif
                CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, device.texture_cache_context, NULL, &__ref);
            NSASSERT(!err);
        }];
    });

    [TGLDevice runTextureCacheQueueSync:^{
        block(__ref);
    }];
}

+ (void)flushTextureCache
{
    [TGLDevice useFastTextureCacheRef:^(CVOpenGLESTextureCacheRef ref) {
        CVOpenGLESTextureCacheFlush(ref, 0);
    }];
}

/*
+ (void)fenceSync
{
    GLsync sync = glFenceSyncAPPLE(GL_SYNC_GPU_COMMANDS_COMPLETE_APPLE, 0);GLASSERT;

    if (!glIsSyncAPPLE(sync)) {
        glFinish();
        ERROR("glFenceSyncAPPLE returned invalid object");
        return;
    }

    glFlush();
    GLenum result = glClientWaitSyncAPPLE(sync, GL_SYNC_FLUSH_COMMANDS_BIT_APPLE, GL_TIMEOUT_IGNORED_APPLE);GLASSERT;

    glDeleteSyncAPPLE(sync);GLASSERT;
}
*/

+ (void)fenceSync
{
    TGLDevice *device = [TGLDevice sharedInstance];
    GLsync sync;
    @synchronized(device) {
        sync = glFenceSyncAPPLE(GL_SYNC_GPU_COMMANDS_COMPLETE_APPLE, 0);GLASSERT;
    }
    GLenum result = glClientWaitSyncAPPLE(sync, GL_SYNC_FLUSH_COMMANDS_BIT_APPLE, GL_TIMEOUT_IGNORED_APPLE);GLASSERT;

    @synchronized(device) {
        if (glIsSyncAPPLE(sync)) {
            glDeleteSyncAPPLE(sync);GLASSERT;
        } else {
            ERROR("glIsSyncAPPLE may be failed with wait-sync result: %08x", result);
        }
    }
}

@end

