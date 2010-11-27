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


// a simple test (disabled by if-guard by default)
#if 0
static inline void hatomic_flags_test() {
  hatomic_flags_t flags = 0;
  
  #define hafdo(op, n) do { \
    bool rv = hatomic_flags_##op(&flags, n); \
    fprintf(stderr, "hatomic_flags_%-5s(%2d) -> %s \t %s\n", \
    #op, n, rv?"true ":"false", debug_bits32(flags)); } while(0)
  
  hafdo(set, 31);
  hafdo(set, 1);
  hafdo(set, 24);
  hafdo(set, 7);
  hafdo(test, 7);
  hafdo(clear, 7);
  hafdo(clear, 7);
  hafdo(test, 7);
  hafdo(test, 24);
  hafdo(test, 31);
  hafdo(test, 3);
  hafdo(set, 3);
  hafdo(test, 3);
  flags = 0;
  for (int i=0;i<32;++i) { hafdo(set, i); }
  for (int i=0;i<32;++i) assert(hatomic_flags_test(&flags, i) == true);
  for (int i=0;i<16;++i) { hafdo(clear, i); }
  for (int i=0;i<16;++i) assert(hatomic_flags_test(&flags, i) == false);
  for (int i=16;i<32;++i) assert(hatomic_flags_test(&flags, i) == true);
  for (int i=16;i<32;++i) { hafdo(clear, i); }
  for (int i=16;i<32;++i) assert(hatomic_flags_test(&flags, i) == false);
  
  #undef hafdo
}
#endif

#endif  // HATOMIC_FLAGS_H_
