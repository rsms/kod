// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/*
 * hatomic_flags -- atomically and independently set, test and clear 32 flags.
 *
 * Currently only supports Mac OS X.
 *
 * Example:
 *
 *    hatomic_flags_t flags = 0;
 *    hatomic_flags_set(&flags, 4);    // --> true  "did set"
 *    hatomic_flags_test(&flags, 4);   // --> true  "is set"
 *    hatomic_flags_clear(&flags, 4);  // --> true  "did clear"
 *    hatomic_flags_test(&flags, 4);   // --> false "not set"
 *
 */
#ifndef HATOMIC_FLAGS_H_
#define HATOMIC_FLAGS_H_

#include <stdint.h>
#include <stdbool.h>
#include <assert.h>
#include <libkern/OSAtomic.h>

// flags storage type
typedef volatile int32_t hatomic_flags_t;

// limits
#define HATOMIC_FLAG_MIN 0
#define HATOMIC_FLAG_MAX 31

// Set |flag| in |flags| unless already set. Returns true if set.
static inline bool hatomic_flags_set(hatomic_flags_t *flags, uint32_t flag) {
  assert(flag <= HATOMIC_FLAG_MAX);
  return !OSAtomicTestAndSetBarrier(flag, flags);
}

// Clear |flag| in |flags| if set. Returns false if |flag| was not set (no-op).
static inline bool hatomic_flags_clear(hatomic_flags_t *flags, uint32_t flag) {
  assert(flag <= HATOMIC_FLAG_MAX);
  return OSAtomicTestAndClearBarrier(flag, flags);
}

// Test if |flag| is set in |flags|
static inline bool hatomic_flags_test(hatomic_flags_t *flags, uint32_t flag) {
  // since we use write barriers on set and clear, direct reads are safe
  assert(flag <= HATOMIC_FLAG_MAX);
  return (*((char*)flags + (flag >> 3))) & (0x80 >> (flag & 7));
}

#endif  // HATOMIC_FLAGS_H_
