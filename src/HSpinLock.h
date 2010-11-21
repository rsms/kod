#ifndef H_SPIN_LOCK_H_
#define H_SPIN_LOCK_H_

#import <libkern/OSAtomic.h>

#ifdef __cplusplus

class HSpinLock {
  volatile OSSpinLock lock_;

 public:
  HSpinLock() : lock_(0) { }
  inline void lock() { OSSpinLockLock(&lock_); }
  inline bool tryLock() { return OSSpinLockTry(&lock_); }
  inline void unlock() { OSSpinLockUnlock(&lock_); }

  class Scope {
   private:
    HSpinLock &sl_;
    Scope(Scope const &);
    Scope & operator=( Scope const & );
   public:
    explicit Scope(HSpinLock & sl) : sl_(sl) { sl.lock(); }
    ~Scope() { sl_.unlock(); }
  };
};

/**
 * Critical section helper.
 *
 * Example:
 *
 *   HSpinLock sl;
 *   // do something non-critical here
 *   HSpinLockSync(sl) {
 *     // the lock has been aquired
 *     // do critical stuff
 *   }
 *   // the lock has been released
 *
 */
#define HSpinLockSync(sl) \
  for (_HSpinLockScopeLocker __hslsl(sl); __hslsl.lockOnce() ; )
// push _HSpinLockUnlocker(sl)
// __hslsl.lockOnce() {
//   used_ => false
//   sl.lock()
//   used_ = true
// } => true
// exec ...
// __hslsl.lockOnce() {
//   used_ => true
// } => false
// break
// pop ~_HSpinLockScopeLocker {
//  sl.unlock();
// }


/**
 * Like HSpinLockSync, but w/o a scope helper. It's a light-weight construct
 * which does not handle premature breaks, like return statements.
 */
#define HSpinLockSync2(sl) \
  for (int8_t __hsl_x = 2 ; \
       (--__hsl_x && __hsl_lock2(sl)) || __hsl_unlock2(sl) ; )
// __hsl_x = 2
// __hsl_x -= 1 => 1
// __hsl_lock2(sl)
// exec ...
// __hsl_x -= 1 => 0
// __hsl_unlock2(sl)
// break


// Helpers for the critical section macros

class _HSpinLockScopeLocker {
 public:
  bool used_;
  HSpinLock &sl_;
  explicit _HSpinLockScopeLocker(HSpinLock & sl) : sl_(sl), used_(false) { }
  ~_HSpinLockScopeLocker() { sl_.unlock(); }
  inline bool lockOnce() {
    if (used_) return false;
    sl_.lock();
    return (used_ = true);
  }
};

static inline bool __hsl_lock2(HSpinLock & sl) { sl.lock(); return true; }
static inline bool __hsl_unlock2(HSpinLock & sl) { sl.unlock(); return false; }

#endif  // __cplusplus
#endif  // H_SPIN_LOCK_H_
