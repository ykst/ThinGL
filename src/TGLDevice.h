// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <GLKit/GLKit.h>
#import "TGLProgram.h"

#define GLBUFFER_OFFSET(x) ((const GLvoid *)(x))
#if 1
#define GLCHECK(action) do {action;NSASSERT(glGetError() == 0);} while(0)
#else
#define GLCHECK(action) action
#endif


#define GLASSERT do {\
GLenum ____err = glGetError();\
if (____err != GL_NO_ERROR) {\
NSLog(@"glGetError() = 0x%04x", ____err);\
NSASSERT(!"GLASSERT");\
}\
} while(0)


// http://my.safaribooksonline.com/book/programming/opengl/9780321563835/gl-half-float-oes/app01lev1sec2
// -15 stored using a single precision bias of 127
#define HALF_FLOAT_MIN_BIASED_EXP_AS_SINGLE_FP_EXP 0x38000000
// max exponent value in single precision that will be converted
// to Inf or Nan when stored as a half-float
#define HALF_FLOAT_MAX_BIASED_EXP_AS_SINGLE_FP_EXP 0x47800000

// 255 is the max exponent biased value
#define FLOAT_MAX_BIASED_EXP (0xFF << 23)

#define HALF_FLOAT_MAX_BIASED_EXP (0x1F << 10)

typedef uint16_t    hfloat;

static inline hfloat
convertFloatToHFloat(float f)
{
    float _f = f;
    uint32_t x = *(uint32_t *)(&_f);
    uint32_t sign = (uint32_t)(x >> 31);
    uint32_t mantissa;
    uint32_t exp;
    hfloat          hf;

    // get mantissa
    mantissa = x & ((1 << 23) - 1);
    // get exponent bits
    exp = x & FLOAT_MAX_BIASED_EXP;
    if (exp >= HALF_FLOAT_MAX_BIASED_EXP_AS_SINGLE_FP_EXP)
    {
        // check if the original single precision float number is a NaN
        if (mantissa && (exp == FLOAT_MAX_BIASED_EXP))
        {
            // we have a single precision NaN
            mantissa = (1 << 23) - 1;
        }
        else
        {
            // 16-bit half-float representation stores number as Inf
            mantissa = 0;
        }
        hf = (((hfloat)sign) << 15) | (hfloat)(HALF_FLOAT_MAX_BIASED_EXP) |
        (hfloat)(mantissa >> 13);
    }
    // check if exponent is <= -15
    else if (exp <= HALF_FLOAT_MIN_BIASED_EXP_AS_SINGLE_FP_EXP)
    {

        // store a denorm half-float value or zero
        exp = (HALF_FLOAT_MIN_BIASED_EXP_AS_SINGLE_FP_EXP - exp) >> 23;
        mantissa >>= (14 + exp);

        hf = (((hfloat)sign) << 15) | (hfloat)(mantissa);
    }
    else
    {
        hf = (((hfloat)sign) << 15) |
        (hfloat)((exp - HALF_FLOAT_MIN_BIASED_EXP_AS_SINGLE_FP_EXP) >> 13) |
        (hfloat)(mantissa >> 13);
    }

    return hf;
}

static inline float
convertHFloatToFloat(hfloat hf)
{
    uint32_t sign = (unsigned int)(hf >> 15);
    uint32_t mantissa = (unsigned int)(hf & ((1 << 10) - 1));
    uint32_t exp = (unsigned int)(hf & HALF_FLOAT_MAX_BIASED_EXP);
    uint32_t f;

    if (exp == HALF_FLOAT_MAX_BIASED_EXP)
    {
        // we have a half-float NaN or Inf
        // half-float NaNs will be converted to a single precision NaN
        // half-float Infs will be converted to a single precision Inf
        exp = FLOAT_MAX_BIASED_EXP;
        if (mantissa)
            mantissa = (1 << 23) - 1;    // set all bits to indicate a NaN
    }
    else if (exp == 0x0)
    {
        // convert half-float zero/denorm to single precision value
        if (mantissa)
        {
            mantissa <<= 1;
            exp = HALF_FLOAT_MIN_BIASED_EXP_AS_SINGLE_FP_EXP;
            // check for leading 1 in denorm mantissa
            while ((mantissa & (1 << 10)) == 0)
            {
                // for every leading 0, decrement single precision exponent by 1
                // and shift half-float mantissa value to the left
                mantissa <<= 1;
                exp -= (1 << 23);
            }
            // clamp the mantissa to 10-bits
            mantissa &= ((1 << 10) - 1);
            // shift left to generate single-precision mantissa of 23-bits
            mantissa <<= 13;
        }
    }
    else
    {
        // shift left to generate single-precision mantissa of 23-bits
        mantissa <<= 13;
        // generate single precision biased exponent value
        exp = (exp << 13) + HALF_FLOAT_MIN_BIASED_EXP_AS_SINGLE_FP_EXP;
    }

    f = (sign << 31) | exp | mantissa;
    return *((float *)&f);
}

@interface TGLDevice : NSObject

+(void)runMainThreadSync:(void (^)())block;
+(void)runPassiveContextSync:(void (^)())block;
+(void)runTextureCacheQueueSync:(void (^)())block;
+(void)setContext:(EAGLContext *)context;

+(EAGLContext *)setNewContext;
+(EAGLContext *)createContext;
+(EAGLContext *)currentContext;

//+(CVOpenGLESTextureCacheRef)getFastTextureCacheRef;
+ (void)flushTextureCache;
+ (void)useFastTextureCacheRef:(void (^)(CVOpenGLESTextureCacheRef ref))block;
+(void)fenceSync;

@end



