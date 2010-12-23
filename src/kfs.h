// file system utils
#ifndef K_FS_H_
#define K_FS_H_

#include <stdbool.h>

// test if file at path exists and is executable
bool kfs_isexec(const char *path);

// Derive absolute path for named executable (like the "which" tool). Returns a
// newly allocated string which you need to free() or NULL if not found.
char *kfs_which(const char *filename);

#endif  // K_FS_H_
