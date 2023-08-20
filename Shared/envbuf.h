//
//  envbuf.h
//  launchdhook
//
//  Created by Serena on 20/08/2023.
//  

#ifndef envbuf_h
#define envbuf_h

int envbuf_len(const char *envp[]);
char **envbuf_mutcopy(const char *envp[]);
void envbuf_free(char *envp[]);
int envbuf_find(const char *envp[], const char *name);
void envbuf_unsetenv(char **envpp[], const char *name);
void envbuf_setenv(char **envpp[], const char *name, const char *value);
const char *envbuf_getenv(const char *envp[], const char *name);


#endif /* envbuf_h */
