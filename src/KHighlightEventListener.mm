#import "KHighlightEventListener.h"
#import <ChromiumTabs/common.h>

KHighlightEventListenerProxy::KHighlightEventListenerProxy(
    NSObject<KHighlightEventListener> *obj) {
  obj_ = [obj retain];
}

KHighlightEventListenerProxy::~KHighlightEventListenerProxy() {
  [obj_ release]; obj_ = NULL;
}

void KHighlightEventListenerProxy::notify(
    const srchilite::HighlightEvent &event) {
  if (obj_) {
    [obj_ handleHighlightEvent:event];
  }
}
