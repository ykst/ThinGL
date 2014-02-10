// Copyright (c) 2014 Yohsuke Yukishita
// This software is released under the MIT License: http://opensource.org/licenses/mit-license.php

#import "NSObject+SimpleArchiver.h"
#import <objc/runtime.h>
#import "Utility.h"

@implementation NSObject(SimpleArchiver)

+ (NSString *)_makeArchivePath:(Class)cls forKey:(NSString *)key
{
    NSString *plain = NSPRINTF(@"_#SA_%@_%@", NSStringFromClass(cls), key);
    NSString *hashed = [[plain dataUsingEncoding:NSUTF8StringEncoding] sha1String];
    NSArray *document_paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                        NSUserDomainMask, YES);
    NSString *documents_path = [document_paths objectAtIndex:0];
    NSString *path = NSPRINTF(@"%@/%@", documents_path, hashed);

    return path;
}

- (BOOL)simpleArchiveForKey:(NSString *)key
{
    NSString *archive_key = [NSObject _makeArchivePath:[self class] forKey:key];

    unsigned count;
    objc_property_t *properties = class_copyPropertyList([self class], &count);

    if (count == 0) return NO;

    NSMutableArray *keys = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count; ++i) {
        objc_property_t property = properties[i];
        keys[i] = [NSString stringWithUTF8String:property_getName(property)];
    }

    NSDictionary *dict = [self dictionaryWithValuesForKeys:keys];

    BOOL ret = [NSKeyedArchiver archiveRootObject:dict toFile:archive_key];
    
    return ret;
}

+ (id)simpleUnarchiveForKey:(NSString *)key
{
    NSString *archive_key = [NSObject _makeArchivePath:[self class] forKey:key];

    NSDictionary *dict = [NSKeyedUnarchiver unarchiveObjectWithFile:archive_key];

    if (!dict) return nil;

    NSObject *obj = [[self class] new];

    [obj setValuesForKeysWithDictionary:dict];
    
    return obj;
}
@end

