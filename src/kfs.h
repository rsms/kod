// file system utils
#ifndef K_FS_H_
#define K_FS_H_

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// test if file at path exists and is executable
bool kfs_isexec(const char *path);

// Derive absolute path for named executable (like the "which" tool). Returns a
// newly allocated string which you need to free() or NULL if not found.
char *kfs_which(const char *filename);

// iterate over directory trees in |dirs| asynchronously
void kfs_iterdirs_async(NSArray *dirs,
                        BOOL(^entryHandler)(NSError**,NSURL*),
                        void(^callback)(NSError*));

/*!
 * Iterate a directory, invoking a block for each entry or on an error.
 *
 * @param dirURL URL of the directory to
 * @param entryHandler Block called for every entry. Returning NO will abort the
 *                     iteration. If a block returns NO, it should set an error.
 * @param prefetchKeys NSURL keys to pre-fetch. Pass nil to disable.
 * @param options Could for instance be NSDirectoryEnumerationSkipsHiddenFiles
 */
NSError *kfs_iterdir_foreach(NSURL *dirURL,
                             BOOL(^entryHandler)(NSError**,NSURL*),
                             NSArray *prefetchKeys,
                             NSDirectoryEnumerationOptions options);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // K_FS_H_
