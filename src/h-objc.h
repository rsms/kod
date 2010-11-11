/*
 * Objective-C utilities
 *
 * Copyright 2010 Rasmus Andersson <http://hunch.se/>
 * Licensed under the MIT license.
 */

#ifndef H_OBJC_H_
#define H_OBJC_H_
#ifdef __OBJC__

#import <libkern/OSAtomic.h>

/**
 * Atomically perform (dst = src, return olddst).
 *
 * Common pattern for retain/release:
 *
 *   [h_objc_swap(&[member_ retain], newobj) release];
 */
inline id h_objc_swap(id volatile *dst, id src) {
  id old;
  while (1) {
    old = *dst;
    if (OSAtomicCompareAndSwapPtrBarrier(old, src, (void* volatile*)dst))
      break;
  }
  return old;
}


/// Exchange dst with src, retaining src and releasing dst afterwards.
inline id h_objc_xch(id *dst, id src) {
  id old = *dst;
  *dst = [src retain];
  [old release];
  return old;
}

#endif // __OBJC__
#endif // H_OBJC_H_
