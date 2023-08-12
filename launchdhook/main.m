//
//  main.m
//  launchdhook
//
//  Created by Serena on 12/08/2023.
//  

#import <Foundation/Foundation.h>
#include "hooks.h"

__attribute__((constructor)) void initializer(void) {
    NSLog(@"Season changing,\n");
    NSLog(@"Summer starts to leave,\n");
    NSLog(@"Autumn falls on me,\n");
    NSLog(@"Fall, Winter and Spring.\n");
    
    // initialize our hooks
    initIPCHooks();
}
