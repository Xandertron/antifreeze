// http detour - just logs URLs and blackholes them to a local IP which times out.

#include <stddef.h>
#include <stdio.h>

#define URL_CAP  256     /* rolling window size */
#define URL_MAX  1024    /* max bytes per URL incl NUL */
#define CURLOPT_URL 10002
#define BLACKHOLE_URL "http://192.168.1.234/"

typedef void CURL;

/* ring buffer to push URLs without blocking or doing anything expensive in the detour */
char         url_ring[URL_CAP][URL_MAX] = {0};
unsigned int url_head = 0;

static void push_url(const char* s, size_t n) {
    if (!s) return;
    unsigned int slot = url_head % URL_CAP;
    if (n > URL_MAX - 1) n = URL_MAX - 1;
    for (size_t i = 0; i < n; ++i) url_ring[slot][i] = s[i];
    url_ring[slot][n] = 0;
    url_head++;          /* publish only after the payload is complete */
}

int (*original)(CURL* curl, int option, ...);
int detour(CURL* curl, int option, ...) {
  if (option == CURLOPT_URL) {
    // Blackhole any request. Could do filtering later but it might
    // noticeably degrade performance if we do too much work here.
    va_list args;
    va_start(args, option);
    const char* url = va_arg(args, const char*);
    va_end(args);

    int n = 0;
    while (url[n] && n < URL_MAX - 1) n++;
    push_url(url, n);

    return original(curl, option, BLACKHOLE_URL);
  }

  return original(curl, option);
}
