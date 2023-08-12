//
//  main.c
//  jailbreakd
//
//  Created by Serena on 12/08/2023.
//  

#include <stdio.h>
#import <jailbreakd-Swift.h>

int main(int argc, char **argv) {
    NSError *error;
    
    [JailbreakdServer mainAndReturnError:&error];
    
    if (error) {
        fprintf(stderr, "Jailbreakd Error: %s (Error Code: %d)", error.localizedDescription.UTF8String, (int)error.code);
        return (int)error.code;
    }
    
    return 0;
}
