#ifndef K_CORE_SUDDEN_TERMINATION_H_
#define K_CORE_SUDDEN_TERMINATION_H_

#ifndef __OBJC__
#error This interface is currentl only supported by Objective-C code
#endif

// Increment the sudden termination counter.
static inline void KSuddenTerminationDisallowIncr() {
  [[NSProcessInfo processInfo] disableSuddenTermination];
}

// Decrement the sudden termination counter. When reaching 0, Kod might get
// SIGKILLed by the kernel (instead of the regular "Quit" apple event).
static inline void KSuddenTerminationDisallowDecr() {
  [[NSProcessInfo processInfo] enableSuddenTermination];
}

#endif  // K_CORE_SUDDEN_TERMINATION_H_
