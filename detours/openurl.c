// Blocks anything from opening a URL.

#include <stddef.h>
#include <stdio.h>

void (*original)(void* this_ptr, const char* url);
void detour(void* this_ptr, const char* url) {
  original(this_ptr, "https://127.0.0.1"); /* still call it, so it does not create a timing difference */
}
