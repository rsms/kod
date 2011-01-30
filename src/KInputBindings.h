#include <tr1/memory>
#include <assert.h>
#include "HUnorderedMap.h"
#import "NSEvent-kod.h"

// an action which is associated with an input sequence in KInputBindings
class KInputAction {
 public:
  virtual BOOL perform(id sender) = 0;
};

typedef std::tr1::shared_ptr<KInputAction> KInputActionPtr;

// an action which invokes a Objective-C selector on its target or sender
class KSelectorInputAction : public KInputAction {
 public:
  KSelectorInputAction(SEL selector, id target=nil) {
    selector_ = selector;
    target_ = [target retain];
  }
  ~KSelectorInputAction() {
    [target_ release];
  }
  BOOL perform(id sender) {
    if (!target_ && [sender respondsToSelector:selector_]) {
      [sender performSelector:selector_];
      return YES;
    } else if (target_ && [target_ respondsToSelector:selector_]) {
      [sender performSelector:selector_ withObject:sender];
      return YES;
    }
    return NO;
  }
 protected:
  SEL selector_;
  id target_;
};

// holds input bindings
class KInputBindings {
 public:
  // map type
  typedef HUnorderedMapSharedPtr<uint64_t, KInputAction> Map;

  // level of the application where an event is bound and active
  enum Level {
    AppLevel = 0,    // events captured when entering the app ("top level")
    TextEditorLevel, // events captured in the text editor
    MaxLevel         // (Never use this)
  };

  static void set(Level level, uint64_t key, KInputAction *action) {
    assert(level < MaxLevel);
    bindings_[level].putSync(key, action);
  }
  // bind |action| to a sequence (e.g. "M-S-r")
  static BOOL set(Level level, NSString *seq, KInputAction *action);

  // find an action for an event. returns null if not found.
  static KInputAction *get(Level level, uint64_t key) {
    assert(level < MaxLevel);
    return bindings_[level].getSync(key);
  }
  static KInputAction *get(Level level, NSEvent *event) {
    return get(level, [event kodHash]);
  }
  static KInputAction *get(Level level, NSString *seq);

  // retrieve mappings for |level|. |level| must be within [0-MaxLevel)
  static Map& get(Level level) { return bindings_[level]; }

  // remove any binding for |key|. returns true if found and removed.
  static BOOL remove(Level level, uint64_t key) {
    assert(level < MaxLevel);
    return bindings_[level].eraseSync(key) != 0;
  }

  // removes |key| from all levels and returns the number of bindings removed
  static size_t remove(uint64_t key);

  // removes all bindings (from all levels if level is MaxLevel)
  static void clear(Level level=MaxLevel);

  // parse a single sequence (e.g. "M-S-r") into it's canonical key
  // returns 0 (zero) to indicate a bad/illegal sequence.
  static uint64_t parseSequence(NSString *seq);

 protected:
  static Map bindings_[MaxLevel];
};
