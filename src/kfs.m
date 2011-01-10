#import "common.h"
#import "kfs.h"

#include <sys/stat.h>


bool kfs_isexec(const char *name) {
  struct stat s;
  return (!access(name, X_OK) && !stat(name, &s) && S_ISREG(s.st_mode));
}


char *_concat_path_file(const char *path, const char *filename) {
  char *outbuf;
  char *lc;

  lc = (char *)path + strlen(path) - 1;
  if (lc < path || *lc != '/') {
    lc = NULL;
  }
  while (*filename == '/') {
    filename++;
  }
  outbuf = malloc(strlen(path) + strlen(filename) + 1 + (lc == NULL ? 1 : 0));
  sprintf(outbuf, "%s%s%s", path, (lc == NULL) ? "/" : "", filename);

  return outbuf;
}


char *kfs_which(const char *filename) {
  char *path, *p, *n;

  path = getenv("PATH");
  if (!path) {
    return NULL;
  }

  p = path = strdup(path);
  while (p) {
    n = strchr(p, ':');
    if (n) {
      *n++ = '\0';
    }
    if (*p != '\0') {
      p = _concat_path_file(p, filename);
      if (kfs_isexec(p)) {
        free(path);
        return p;
      }
      free(p);
    }
    p = n;
  }
  free(path);
  return NULL;
}
