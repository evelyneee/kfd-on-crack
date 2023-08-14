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
    
    [JailbreakdServer initializeServerMainWithError:&error];
    
    if (error) {
        fprintf(stderr, "Jailbreakd Error: %s", error.localizedDescription.UTF8String);
        return error.code;
    }
    
    return 0;
}
