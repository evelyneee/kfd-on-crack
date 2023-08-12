//
//  Logging.h
//  kfd
//
//  Created by Serena on 11/08/2023.
//  

#ifndef Logging_h
#define Logging_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, LogLevel) {
    LogLevelNormal,
    LogLevelFatalError,
};

/// Represents an individual log, with a level and the log's text.
@interface Log : NSObject

+(instancetype)logWithText: (NSString *)text level: (LogLevel)level;

-(instancetype)init NS_UNAVAILABLE;

@property NSString *text;
@property LogLevel level;

@end

typedef void(^LoggerUpdateCallback)(Log *);

@interface Logger : NSObject

@property (class, readonly) Logger *sharedLogger;

@property LoggerUpdateCallback callback;
@property NSMutableArray <Log *> *entireLog;
@property dispatch_queue_t fileMonitorQueue;
@property FILE *basebins_file_log;

-(void)startListeningToFileLogChanges;
@end

// C Support
void kfd_log(const char *fmt, ...);

NS_ASSUME_NONNULL_END

#endif /* Logging_h */
