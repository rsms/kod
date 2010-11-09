#import <srchilite/highlighteventlistener.h>
#import <srchilite/highlightevent.h>
#import <srchilite/highlightrule.h>
#import <srchilite/highlighttoken.h>
#ifndef K_HIGHLIGHT_EVENT_LISTENER_H_
#define K_HIGHLIGHT_EVENT_LISTENER_H_

@protocol KHighlightEventListener
- (void)handleHighlightEvent:(const srchilite::HighlightEvent &)event;
@end

class KHighlightEventListenerProxy : public srchilite::HighlightEventListener {
  NSObject<KHighlightEventListener> *obj_;
 public:
	KHighlightEventListenerProxy(NSObject<KHighlightEventListener> *obj);
	virtual ~KHighlightEventListenerProxy();
  void notify(const srchilite::HighlightEvent &event);
};

#endif // K_HIGHLIGHT_EVENT_LISTENER_H_
