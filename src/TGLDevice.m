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

        [__instance _setup];
    });
    return __instance;
}

- (void)_setup
{
    self.root_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:nil];
    self.texture_cache_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:self.root_context.sharegroup];
    _texture_cache_queue = dispatch_queue_create("com.monadworks.tgl.texture_cache", 0);

    dispatch_queue_set_specific(_texture_cache_queue, &_texture_cache_queue, (__bridge void *)self, NULL);
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
    NSASSERT([EAGLContext currentContext]);
    block();
    [TGLDevice fenceSync];
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

- (void)runTextureCacheQueue:(void (^)())block
{
    if (dispatch_get_specific(&_texture_cache_queue) == (__bridge void *)self) {
        NSASSERT([EAGLContext currentContext] == _texture_cache_context);
        block();
        glFlush();
        [TGLDevice fenceSync];
    } else {
        dispatch_sync(_texture_cache_queue, ^{
            [TGLDevice setContext:_texture_cache_context];
            block();
            glFlush();
            [TGLDevice fenceSync];
        });
    }
}

+ (void)runTextureCacheQueueSync:(void (^)())block
{
    TGLDevice *device = [TGLDevice sharedInstance];

    [device runTextureCacheQueue:block];
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

- (void)runMain:(void (^)(EAGLContext *))block
{
    EAGLContext *current_context = [EAGLContext currentContext];

    if (current_context != self.root_context) {
        [EAGLContext setCurrentContext:self.root_context];
    }

    block([EAGLContext currentContext]);

    [TGLDevice fenceSync];
}

+ (void)useFastTextureCacheRef:(void (^)(CVOpenGLESTextureCacheRef))block
{
    static CVOpenGLESTextureCacheRef ref = NULL;
    static dispatch_once_t __once_token;

    dispatch_once(&__once_token, ^{
        TGLDevice *device = [TGLDevice sharedInstance];

        [TGLDevice runTextureCacheQueueSync:^{
            CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, device.texture_cache_context, NULL, &ref);
            NSASSERT(!err);
        }];
    });

    [TGLDevice runTextureCacheQueueSync:^{
        block(ref);
    }];
}

+ (void)flushFastTextureCacheRef
{
    [TGLDevice useFastTextureCacheRef:^(CVOpenGLESTextureCacheRef ref) {
        CVOpenGLESTextureCacheFlush(ref, 0);
    }];
}

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
            ERROR("glIsSyncAPPLE faild with wait-sync result: %08x", result);
        }
    }
}

@end

