// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import <pthread.h>
#import "TGLDevice.h"

@interface TGLDevice() {
    dispatch_queue_t _texture_cache_queue;
    pthread_mutex_t _mutex;
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
        pthread_mutex_init(&_mutex, NULL);
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

- (void)lock
{
    pthread_mutex_lock(&_mutex);
}

- (void)unlock
{
    pthread_mutex_unlock(&_mutex);
}

+ (void)fenceSync
{
    TGLDevice *device = [TGLDevice sharedInstance];

    // NOTE:
    // This lock is conceptually unnecessary but there are witnesses without doing this
    // may cause fatal crash on multi-threaded multi-context, only in iOS6.
    [device lock];
    GLsync sync = glFenceSyncAPPLE(GL_SYNC_GPU_COMMANDS_COMPLETE_APPLE, 0);GLASSERT;
    [device unlock];

    int yield_count = 0;
    GLenum result;

    do {
        // NOTE:
        // glClientWaitSyncAPPLE sometimes spends up lots of CPU by calling mach_absolute_time()
        // while detecting timeout in its busy loop.
        // So we do not count on its blocking mechanism considering CPU effeciency in multi threads.
        result = glClientWaitSyncAPPLE(sync, GL_SYNC_FLUSH_COMMANDS_BIT_APPLE, 0);GLASSERT;

        if (result == GL_TIMEOUT_EXPIRED_APPLE) {
            if (yield_count < 1) {
                ++yield_count;
                sched_yield();
            } else {
                // call glFinish() to avoid bursting sched_yield()
                glFinish();
                break;
            }
        } else {
            break;
        }
    } while (1);

    [device lock];
    if (glIsSyncAPPLE(sync)) {
        glDeleteSyncAPPLE(sync);GLASSERT;
    } else {
        ERROR("glIsSyncAPPLE may be failed with wait-sync result: %08x", result);
    }
    [device unlock];
}

- (void)dealloc
{
    pthread_mutex_destroy(&_mutex);
}

@end

