// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import <Foundation/Foundation.h>

@protocol TGLBindable <NSObject>
@required
@property (nonatomic, readonly) GLuint name;
- (void)bind;
- (void)bindBlock:(void (^)())block;
+ (void)unbind;

#define TGL_BINDBLOCK(obj) for (int __bindblock_dummy_idx = ({[(obj) bind]; 0;}); (__bindblock_dummy_idx < 1) || ({[[(obj) class] unbind]; 0;}); ++__bindblock_dummy_idx)
@end

