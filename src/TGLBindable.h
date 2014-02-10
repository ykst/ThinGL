// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import <Foundation/Foundation.h>

@protocol TGLBindable <NSObject>
@required
@property (nonatomic, readonly) GLuint name;
- (void)bind;
- (void)bindBlock:(void (^)())block;
+ (void)unbind;

@end

