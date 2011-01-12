// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "common.h"
#import "kfs.h"

#include <libkern/OSAtomic.h>
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
  outbuf = (char*)malloc(strlen(path) + strlen(filename) + 1
                         + (lc == NULL ? 1 : 0));
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


NSError *kfs_iterdir_foreach(NSURL *dirURL,
                             BOOL(^entryHandler)(NSError**,NSURL*),
                             NSArray *prefetchKeys,
                             NSDirectoryEnumerationOptions options) {
  NSFileManager *fm = [NSFileManager defaultManager];
  __block NSError *error = nil;
  NSDirectoryEnumerator *en =
            [fm enumeratorAtURL:dirURL
     includingPropertiesForKeys:prefetchKeys
                        options:options
                   errorHandler:^(NSURL *url, NSError *err) {
    if (!entryHandler(&err, url)) {
      error = err;
      return NO;
    }
    return YES;
  }];
  for (NSURL *url in en) {
    NSError *err = nil;
    if (!entryHandler(&err, url)) {
      error = err;
      break;
    }
  }
  return error;
}


void kfs_iterdirs_async(NSArray *dirs,
                        BOOL(^entryHandler)(NSError**,NSURL*),
                        void(^callback)(NSError*)) {
  // copy to avoid race cond: count vs actual
  assert(dirs);
  dirs = [dirs copy];
  assert(dirs.count <= INT32_MAX);
  __block int32_t countdown = dirs.count;
  if (countdown == 0) {
    callback(nil);
    [dirs release];
    return;
  }

  // dispatch queue
  dispatch_queue_t queue = dispatch_get_global_queue(0,0);

  // retain handler and callback
  __block BOOL(^_entryHandler)(NSError**,NSURL*) = [entryHandler copy];
  if (callback) callback = [callback copy];
  Class NSURLClass = [NSURL class];

  // dispatch each operation
  [dirs retain]; //< we need to retain this for some reason
  for (NSURL *dirURL_ in dirs) {
    dispatch_async(queue, ^{
      NSAutoreleasePool *pool = [NSAutoreleasePool new];
      // scan directory
      // convert path string to URL if neccessary
      NSURL *dirURL = dirURL_;
      if (![dirURL isKindOfClass:NSURLClass]) {
        assert([dirURL isKindOfClass:[NSString class]]);
        dirURL = [NSURL fileURLWithPath:(NSString*)dirURL];
      }
      if (!entryHandler) {
        // chain was aborted by an error
        [pool drain];
        return;
      }
      // synchronous readdir (deep)
      NSError *error = kfs_iterdir_foreach(dirURL, _entryHandler, nil, 0);
      // decrement countdown
      uint32_t n = OSAtomicDecrement32(&countdown);
      // if we hit an error and we aren't the last job to finish...
      if (error && n != 0) {
        // ...cmpxch countdown to 0
        if (OSAtomicCompareAndSwap32(n, 0, &countdown)) {
          // we know that we "got number zero"
          n = 0;
        }
      }
      if (n == 0 && h_casid((id volatile*)&_entryHandler, nil)) {
        // we are the last job finishing (or we are responsible for aborting
        // due to an error)
        if (callback) {
          callback(error);
          [callback release];
        }
        [dirs release];
      }
      [pool drain];
    });
  }
  [dirs release];
}
