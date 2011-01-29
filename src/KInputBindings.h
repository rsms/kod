#include <map>
#include <string>
#include <tr1/memory>
#include "HUnorderedMap.h"

class KInputAction;
typedef std::tr1::shared_ptr<KInputAction> KInputActionPtr;

class KInputAction {
 public:
  virtual BOOL perform(id sender) = 0;
};

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

class KInputBindings {
 public:
  static void set(std::string seq, KInputAction *action) {
    bindings_.putSync(seq, action);
  }
  static void set(NSString *seq, KInputAction *action) {
    set(std::string([seq UTF8String]), action);
  }

  static KInputAction *get(std::string seq) {
    return bindings_.getSync(seq);
  }

  static KInputAction *get(NSEvent *event);

 protected:
  static HUnorderedMapSharedPtr<std::string, KInputAction> bindings_;
};
