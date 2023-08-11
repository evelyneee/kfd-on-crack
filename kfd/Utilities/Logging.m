//
//  Logging.m
//  kfd
//
//  Created by Serena on 11/08/2023.
//  

#import <Foundation/Foundation.h>
#import "Logging.h"

@implementation Log

+ (instancetype)logWithText:(NSString *)text level:(LogLevel)level {
    Log *newLog = [Log new];
    newLog.text = text;
    newLog.level = level;
    return newLog;
}

@end

@implementation Logger
+ (Logger *)sharedLogger {
    static Logger *logger;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        logger = [Logger new];
        logger.entireLog = [NSMutableArray array]; 
    });
    
    return logger;
}


-(void)logString: (NSString *)text level: (LogLevel)level {
    [self log: [Log logWithText:text level:level]];
}

-(void)logString: (NSString *)log level: (LogLevel)level withNewLine: (BOOL)newline {
    NSMutableString *mut = [NSMutableString stringWithString:log];
    if (newline)
        [mut appendString:@"\n"];
    
    [self log:[Log logWithText:mut level:level]];
}

-(void)log: (Log *)log {
    [[self entireLog] addObject:log];
    
    NSLog(@"%@", log.text);
    
    if (self.callback)
        self.callback(log);
}

@end

void kfd_log(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    
    Log *log = [Log logWithText:[[NSString alloc] initWithFormat:@(fmt) arguments:args] level:LogLevelNormal];
    [[Logger sharedLogger] log:log];
    
    va_end(args);
}
