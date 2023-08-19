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
        
        char *basebinLogFilepath = "/var/jb/.basebin_curr_log";
        
        if ([NSFileManager.defaultManager fileExistsAtPath:@(basebinLogFilepath)]) {
            [NSFileManager.defaultManager removeItemAtPath:@(basebinLogFilepath) error:nil];
        }
        
        logger.basebins_file_log = fopen(basebinLogFilepath, "a");
    });
    
    return logger;
}


-(void)logString: (NSString *)text {
    [self log: [Log logWithText:text level:LogLevelNormal]];
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

-(void)startListeningToFileLogChanges {
//    return;
    
    /*
    self.fileMonitorQueue = dispatch_queue_create("com.serena.kfdLogging", DISPATCH_QUEUE_SERIAL);
    
    int fd = open("/var/jb/.basebin_curr_log", O_EVTONLY);
    printf("fd: %d\n", fd);
    
    dispatch_source_t src = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, fd, DISPATCH_VNODE_WRITE, self.fileMonitorQueue);
    
    dispatch_source_set_event_handler(src, ^{
        printf("file was written to!\n");
    });
    
    dispatch_resume(src);
     */
}

@end

void kfd_log(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    
    Log *log = [Log logWithText:[[NSString alloc] initWithFormat:@(fmt) arguments:args] level:LogLevelNormal];
    [[Logger sharedLogger] log:log];
    
    va_end(args);
}
