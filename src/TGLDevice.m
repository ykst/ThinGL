// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import <pthread.h>
#import "TGLDevice.h"

@interface TGLDevice() {
}
@property (nonatomic, readwrite) dispatch_queue_t queue;
@property (nonatomic, readwrite) dispatch_queue_t allocation_queue;
@property (nonatomic, readwrite) EAGLContext *gl_context;
@property (nonatomic, readwrite) EAGLContext *main_context;
@property (nonatomic, readwrite) EAGLContext *allocation_context;
@property (nonatomic, readwrite, weak) TGLProgram *current_program;
@end

@implementation TGLDevice

static void *__openGLESContextQueueKey;
static void *__openGLESAllocQueueKey;
static void *__mainQueueKey;

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
        _queue =  dispatch_queue_create("com.monadworks.GLFlow.openGLESContextQueue", NULL);
        _allocation_queue =  dispatch_queue_create("com.monadworks.GLFlow.openGLESAllocQueue", NULL);

        __openGLESContextQueueKey = &__openGLESContextQueueKey;
        __openGLESAllocQueueKey = &__openGLESAllocQueueKey;
        __mainQueueKey = &__mainQueueKey;

        dispatch_queue_set_specific(self.queue, __openGLESContextQueueKey, (__bridge void *)self, NULL);
        dispatch_queue_set_specific(self.allocation_queue, __openGLESAllocQueueKey, (__bridge void *)self, NULL);
        dispatch_queue_set_specific(dispatch_get_main_queue(), __mainQueueKey, (__bridge void *)self, NULL);

        self.gl_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:nil];

        self.main_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:self.gl_context.sharegroup];
        self.allocation_context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:self.gl_context.sharegroup];
    }
    return self;
}

// TODO coarce
- (void)setContext
{
    if ([EAGLContext currentContext] != self.gl_context) {
        [EAGLContext setCurrentContext:self.gl_context];
    }
}

- (void)setMainContext
{
    if ([EAGLContext currentContext] != self.main_context) {
        [EAGLContext setCurrentContext:self.main_context];
    }
}

- (void)setAllocContext
{
    if ([EAGLContext currentContext] != self.allocation_context) {
        [EAGLContext setCurrentContext:self.allocation_context];
    }
}

// TODO: DRY
+ (void)runOnMainQueueSync:(void (^)(EAGLContext *))block
{
    TGLDevice *device = [TGLDevice sharedInstance];
    EAGLContext *prev_context = [EAGLContext currentContext];
    dispatch_queue_t main_queue = dispatch_get_main_queue();
    if (dispatch_get_specific(__mainQueueKey)) {
        [device setMainContext];
        block(device.main_context);
        [TGLDevice fenceSync];
    } else {
        dispatch_sync(main_queue, ^() {
            [device setMainContext];
            block(device.main_context);
            [TGLDevice fenceSync];
        });
    }
    if (prev_context && prev_context != device.main_context) {
        [EAGLContext setCurrentContext:prev_context];
    }
}

+ (void)runOnAllocQueueSync:(void (^)(EAGLContext *))block
{
    TGLDevice *device = [TGLDevice sharedInstance];
    EAGLContext *prev_context = [EAGLContext currentContext];
    if (dispatch_get_specific(__openGLESAllocQueueKey) == (__bridge void *)device) {
        [device setAllocContext];
        block(device.allocation_context);
        [TGLDevice fenceSync];
    } else {
        dispatch_sync(device.allocation_queue, ^() {
            [device setAllocContext];
            block(device.allocation_context);
            [TGLDevice fenceSync];
        });
    }
    if (prev_context && prev_context != device.allocation_context) {
        [EAGLContext setCurrentContext:prev_context];
    }
}

+ (CVOpenGLESTextureCacheRef)getFastTextureCacheRef
{
    static CVOpenGLESTextureCacheRef ref = NULL;
    static dispatch_once_t __once_token;

    dispatch_once(&__once_token, ^{
        [TGLDevice runOnAllocQueueSync:^(EAGLContext *_) {
            CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, [EAGLContext currentContext], NULL, &ref);
            NSASSERT(!err);
        }];
    });

    return ref;
}

+ (void)runOnProcessQueueSync:(void (^)(EAGLContext *))block
{
    TGLDevice *device = [TGLDevice sharedInstance];
    EAGLContext *prev_context = [EAGLContext currentContext];
    if (dispatch_get_specific(__openGLESContextQueueKey) == (__bridge void *)device) {
        [device setContext];
        block(device.gl_context);
        [TGLDevice fenceSync];
    } else {
        dispatch_sync(device.queue, ^() {
            [device setContext];
            block(device.gl_context);
            [TGLDevice fenceSync];
        });
    }
    if (prev_context && prev_context != device.gl_context) {
        [EAGLContext setCurrentContext:prev_context];
    }
}

+ (void)fenceSync
{
    GLsync sync = glFenceSyncAPPLE(GL_SYNC_GPU_COMMANDS_COMPLETE_APPLE, 0);GLASSERT;
    glClientWaitSyncAPPLE(sync, GL_SYNC_FLUSH_COMMANDS_BIT_APPLE, GL_TIMEOUT_IGNORED_APPLE);GLASSERT;
    glDeleteSyncAPPLE(sync);GLASSERT;
}

@end

