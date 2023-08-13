//
//  SharedInfo.m
//  kfd
//
//  Created by Serena on 13/08/2023.
//  

#import <Foundation/Foundation.h>
#import "Utilities.h"

// Similar to bootInfo in Dopamine.
@interface SharedInfo : NSObject


@property (class, readonly) SharedInfo *shared;

@property NSMutableDictionary *dict;
@property NSURL *fileURL;

-(uint64_t)allproc;

@end


@implementation SharedInfo

+ (SharedInfo *)shared {
    static SharedInfo *singleton;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        singleton = [[SharedInfo alloc] init];
    });
    
    return singleton;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.fileURL = [NSURL fileURLWithPath: prebootPath(@"basebin/boot_info.plist")];
        self.dict = [NSMutableDictionary dictionaryWithContentsOfURL:[self fileURL]];
    }
    return self;
}

@end

