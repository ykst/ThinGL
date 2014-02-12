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
    block([EAGLContext currentContext]);
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

+ (EAGLContext *)currentContext
{
    return [EAGLContext currentContext];
}

+ (void)setNewContext
{
    [TGLDevice setContext:[TGLDevice createContext]];
}

- (void)runMain:(void (^)(EAGLContext *))block
{
    [self setContext];
    TGLDevice *device = [TGLDevice sharedInstance];
    EAGLContext *current_context = [EAGLContext currentContext] ;
    if (current_context == device.root_context) {
        [EAGLContext setCurrentContext:device.root_context];
    }/* else {
        NSASSERT(current_context == device.root_context);
    }*/
    block([EAGLContext currentContext]);
    [TGLDevice fenceSync];
}

+ (CVOpenGLESTextureCacheRef)getFastTextureCacheRef
{
    static CVOpenGLESTextureCacheRef ref = NULL;
    static dispatch_once_t __once_token;

    dispatch_once(&__once_token, ^{
        [TGLDevice runMainThreadSync:^{
            CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, [EAGLContext currentContext], NULL, &ref);
            NSASSERT(!err);
        }];
    });

    return ref;
}

+ (void)fenceSync
{
    GLsync sync = glFenceSyncAPPLE(GL_SYNC_GPU_COMMANDS_COMPLETE_APPLE, 0);GLASSERT;
    glClientWaitSyncAPPLE(sync, GL_SYNC_FLUSH_COMMANDS_BIT_APPLE, GL_TIMEOUT_IGNORED_APPLE);GLASSERT;
    glDeleteSyncAPPLE(sync);GLASSERT;
}

@end

