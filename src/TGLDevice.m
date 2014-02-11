// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import <pthread.h>
#import "TGLDevice.h"

@interface TGLDevice() {
}

@property (nonatomic, readwrite) EAGLContext *root_context;

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
    }
    return self;
}

- (void)setContext
{
    if ([EAGLContext currentContext] == nil) {
        [EAGLContext setCurrentContext:[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:self.root_context.sharegroup]];
    }
}

- (void)runSync:(void (^)(EAGLContext *))block
{
    [self setContext];
    block([EAGLContext currentContext]);
    [TGLDevice fenceSync];
}

+ (void)runOnMainQueueSync:(void (^)(EAGLContext *))block
{
    TGLDevice *device = [TGLDevice sharedInstance];

    if ([NSThread isMainThread]) {
        [device runSync:block];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [device runSync:block];
        });
    }
}

+ (CVOpenGLESTextureCacheRef)getFastTextureCacheRef
{
    static CVOpenGLESTextureCacheRef ref = NULL;
    static dispatch_once_t __once_token;

    dispatch_once(&__once_token, ^{
        [TGLDevice runOnMainQueueSync:^(EAGLContext *_) {
            CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, [EAGLContext currentContext], NULL, &ref);
            NSASSERT(!err);
        }];
    });

    return ref;
}

+ (void)runOnProcessQueueSync:(void (^)(EAGLContext *))block
{
    TGLDevice *device = [TGLDevice sharedInstance];
    [device runSync:block];
}

+ (void)fenceSync
{
    GLsync sync = glFenceSyncAPPLE(GL_SYNC_GPU_COMMANDS_COMPLETE_APPLE, 0);GLASSERT;
    glClientWaitSyncAPPLE(sync, GL_SYNC_FLUSH_COMMANDS_BIT_APPLE, GL_TIMEOUT_IGNORED_APPLE);GLASSERT;
    glDeleteSyncAPPLE(sync);GLASSERT;
}

@end

