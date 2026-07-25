// Blocks outbound http(s) URLs, but lets local content through unchanged
// (asset://, file://, data:, etc.) - DHTML panels use OpenURL both for real
// network requests and for navigating to bundled local html/js (some addons
// use this for tricks glua can't otherwise do, e.g. local audio processing).
// Only the former is a fingerprinting/privacy concern, so only that gets
// blackholed. Every call (allowed or blocked) is logged to a ring buffer,
// same shape as detours/http.c's.

#include <stddef.h>
#include <stdio.h>

#define URL_CAP  256     /* rolling window size */
#define URL_MAX  1024    /* max bytes per URL incl NUL */

/* first byte of each slot is a status tag ('A' = allowed through,
 * 'B' = blackholed), followed by the URL string. */
char         url_ring[URL_CAP][URL_MAX] = {0};
unsigned int url_head = 0;

static int starts_with(const char* s, const char* prefix) {
  unsigned int i = 0;
  while (prefix[i]) {
    if (s[i] != prefix[i]) return 0;
    i++;
  }
  return 1;
}

static int is_remote(const char* url) {
  return starts_with(url, "http://") || starts_with(url, "https://");
}

/* This thunk fires for plain JS execution (e.g. panel:QueueJavascript calls
 * some addons make every frame) as well as real navigation, so only log
 * things that are actually shaped like a URL - otherwise every non-URL JS
 * call passing through here floods the ring/console for no reason. */
static int looks_like_url(const char* s) {
  for (unsigned int i = 0; s[i] && i < 32; ++i) {
    if (s[i] == ':' && s[i + 1] == '/' && s[i + 2] == '/') return 1;
  }
  return starts_with(s, "data:");
}

static void push_entry(char status, const char* s) {
  unsigned int slot = url_head % URL_CAP;
  unsigned int n = 0;
  while (s[n] && n < URL_MAX - 2) n++;
  url_ring[slot][0] = status;
  for (unsigned int i = 0; i < n; ++i) url_ring[slot][1 + i] = s[i];
  url_ring[slot][1 + n] = 0;
  url_head++;          /* publish only after the payload is complete */
}

void (*original)(void* this_ptr, const char* url);
void detour(void* this_ptr, const char* url) {
  if (url && is_remote(url)) {
    push_entry('B', url);
    original(this_ptr, "https://127.0.0.1"); /* still call it, so it does not create a timing difference */
  } else {
    if (url && looks_like_url(url)) {
      push_entry('A', url);
    }
    original(this_ptr, url);
  }
}
