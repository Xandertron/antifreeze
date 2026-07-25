// http detour - blackholes any non-whitelisted URL, logs allow/block decisions
// to a ring buffer. WHITELIST_COUNT/WHITELIST_ENTRIES are placeholders
// substituted by detours/http.lua before this is compiled - see
// lib/http_whitelist.lua for the actual list.

#include <stddef.h>
#include <stdio.h>

#define URL_CAP  256     /* rolling window size */
#define URL_MAX  1024    /* max bytes per URL incl NUL */
#define CURLOPT_URL 10002
#define BLACKHOLE_URL "http://192.168.1.234/"

typedef void CURL;

/* ring buffer to push URLs without blocking or doing anything expensive in
 * the detour. Each slot's first byte is a status tag ('A' = allowed through,
 * 'B' = blackholed), followed by the URL string. */
char         url_ring[URL_CAP][URL_MAX] = {0};
unsigned int url_head = 0;

#define WHITELIST_COUNT __WHITELIST_COUNT__
static const char* whitelist[WHITELIST_COUNT] = { __WHITELIST_ENTRIES__ };

static unsigned int str_len(const char* s) {
    unsigned int n = 0;
    while (s[n]) n++;
    return n;
}

static int bytes_eq(const char* a, const char* b, unsigned int n) {
    for (unsigned int i = 0; i < n; ++i) {
        if (a[i] != b[i]) return 0;
    }
    return 1;
}

static int starts_with(const char* s, unsigned int sLen, const char* prefix, unsigned int prefixLen) {
    if (sLen < prefixLen) return 0;
    return bytes_eq(s, prefix, prefixLen);
}

/* host matches domain if it's an exact match, or ends with ".domain" */
static int host_matches(const char* host, unsigned int hostLen, const char* domain) {
    unsigned int domainLen = str_len(domain);
    if (hostLen == domainLen) {
        return bytes_eq(host, domain, domainLen);
    }
    if (hostLen > domainLen && host[hostLen - domainLen - 1] == '.') {
        return bytes_eq(host + hostLen - domainLen, domain, domainLen);
    }
    return 0;
}

static void push_entry(char status, const char* s, unsigned int n) {
    unsigned int slot = url_head % URL_CAP;
    if (n > URL_MAX - 2) n = URL_MAX - 2;
    url_ring[slot][0] = status;
    for (unsigned int i = 0; i < n; ++i) url_ring[slot][1 + i] = s[i];
    url_ring[slot][1 + n] = 0;
    url_head++;          /* publish only after the payload is complete */
}

static int is_whitelisted(const char* url, unsigned int urlLen) {
    /* GMod uses these internally for local/embedded assets, never a real request */
    if (starts_with(url, urlLen, "asset://", 8)) return 1;
    if (starts_with(url, urlLen, "data:", 5)) return 1;

    const char* p = url;
    unsigned int remaining = urlLen;
    if (starts_with(p, remaining, "http://", 7)) { p += 7; remaining -= 7; }
    else if (starts_with(p, remaining, "https://", 8)) { p += 8; remaining -= 8; }
    else return 0; /* unrecognized scheme, deny by default */

    if (starts_with(p, remaining, "www.", 4)) { p += 4; remaining -= 4; }

    unsigned int hostLen = 0;
    while (hostLen < remaining && p[hostLen] != '/' && p[hostLen] != '?' && p[hostLen] != '#') {
        hostLen++;
    }
    if (hostLen == 0) return 0;

    for (int i = 0; i < WHITELIST_COUNT; ++i) {
        if (host_matches(p, hostLen, whitelist[i])) return 1;
    }
    return 0;
}

int (*original)(CURL* curl, int option, ...);
int detour(CURL* curl, int option, ...) {
  if (option == CURLOPT_URL) {
    va_list args;
    va_start(args, option);
    const char* url = va_arg(args, const char*);
    va_end(args);

    unsigned int n = 0;
    while (url[n] && n < URL_MAX - 1) n++;

    if (is_whitelisted(url, n)) {
      push_entry('A', url, n);
      return original(curl, option, url);
    }

    push_entry('B', url, n);
    return original(curl, option, BLACKHOLE_URL);
  }

  return original(curl, option);
}
