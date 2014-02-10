// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php
#ifndef _ThinGL_Utility_h_
#define _ThinGL_Utility_h_

#ifndef likely
# ifdef __builtin_expect
# define likely(x) __builtin_expect((x), 1)
# else
# define likely(x) (x)
# endif
#endif

#ifndef unlikely
# ifdef __builtin_expect
# define unlikely(x) __builtin_expect((x), 0)
# else
# define unlikely(x) (x)
# endif
#endif

#define ERROR(fmt, ...)  NSLog(@"ERROR :%s:%s:%d: " fmt, __BASE_FILE__, __FUNCTION__, __LINE__, ##__VA_ARGS__)

#ifdef DEBUG
#   define WARN(fmt, ...) NSLog(@"WARN :%s:%s:%d: " fmt, __BASE_FILE__, __FUNCTION__, __LINE__, ##__VA_ARGS__)
#   define INFO(fmt, ...) NSLog(@"INFO :%s:%s:%d: " fmt, __BASE_FILE__, __FUNCTION__, __LINE__, ##__VA_ARGS__)
#   define DBG(fmt, ...) NSLog(@"DBG :%s:%s:%d: " fmt, __BASE_FILE__, __FUNCTION__, __LINE__, ##__VA_ARGS__)
#   define MASSERT(b,action,fmt,...) ({bool __b = (bool)(b); if(unlikely(!(__b))){ ERROR(@"failed (%s): " fmt, #b, ##__VA_ARGS__);action;} __b;})
#   define MEXPECT(b,action,fmt,...) ({bool __b = (bool)(b); if(unlikely(!(__b))){ WARN(@"not expected (%s): " fmt, #b, ##__VA_ARGS__);action;} __b;})
#   define MCHECK(b,action,fmt,...) ({bool __b = (bool)(b);if(unlikely(!(__b))){ DBG(@"? (%s): " fmt, #b, ##__VA_ARGS__);action;} __b;})
#else
#   define WARN(fmt, ...)
#   define INFO(fmt, ...)
#   define DBG(fmt, ...)
#   define MASSERT(b,action,fmt,...) ({bool __b = (bool)(b); if(unlikely(!(__b))){ ERROR(@"failed: " fmt, ##__VA_ARGS__);action;} __b;})
#   define MEXPECT(b,action,fmt,...) ({bool __b = (bool)(b); if(unlikely(!(__b))){ WARN(@"not expected: " fmt, #b, ##__VA_ARGS__);action;} __b;})
#   define MCHECK(b,action,fmt,...) ({bool __b = (bool)(b);if(unlikely(!(__b))){ DBG(@"?: " fmt, ##__VA_ARGS__);action;} __b;})
#endif

#define ASSERT(b,action) MASSERT(b,action,@"")
#define EXPECT(b,action) MEXPECT(b,action,@"")
#define CHECK(b,action) MCHECK(b,action,@"")

#ifdef DEBUG
# define DASSERT(b,action) MASSERT(b,action,"(debug)")
#else
# define DASSERT(b,action)
#endif

#define NSSTR(s) [NSString stringWithCString: (s) encoding:NSUTF8StringEncoding]
#define NSPRINTF(fmt, ...) [NSString stringWithFormat:(fmt), ##__VA_ARGS__]

#define ONCE(action) do {\
static dispatch_once_t ____once_token;\
dispatch_once(&____once_token, ^{\
action;\
});\
} while(0)

#define STRINGIFY(x) #x
#define STRINGIFY2(x) STRINGIFY(x)
#define NSSTRINGIFY(text) @ STRINGIFY2(text)

#define NSASSERT(b) NSAssert((b), @"NSAssert on %s:%s:%d:(%s)", __BASE_FILE__, __FUNCTION__, __LINE__, STRINGIFY2(b))

#define NSPOINTER(ptr) ([NSValue valueWithPointer:(ptr)])


#endif

