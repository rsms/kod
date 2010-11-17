#import "KPtrHashTable.h"
#import <boost/shared_ptr.hpp>
#import <CSS/CSS.h>

class KStyleElement;
@class KStyle;

extern NSString const * KStyleDidChangeNotification;
typedef void (^KStyleLoadCallback)(NSError*, KStyle*);

/**
 * Represents a style (e.g. default.css)
 */
@interface KStyle : NSObject {
  CSSContext* cssContext_;
  KStyleElement *catchAllElement_;

  /// Contains KStyleElement mapped by their string symbols.
  KPtrHashTable<KStyleElement> elements_;
  OSSpinLock elementsSpinLock_;
}

#pragma mark -
#pragma mark Getting shared instances

/// An empty style
+ (KStyle*)emptyStyle;

/// Retrieve a style
+ (void)styleAtURL:(NSURL*)url
      withCallback:(void(^)(NSError *err,KStyle *style))cb;

/// Retrieve the default style (the users' current default style)
+ (void)defaultStyleWithCallback:(void(^)(NSError *err,KStyle *style))cb;

#pragma mark -
#pragma mark Initialization and deallocation

- (id)initWithCSSContext:(CSSContext*)cssContext;

- (id)initWithCatchAllElement:(KStyleElement*)element;

/// Reload from underlying file (this is an atomic operation)
//- (void)reloadWithCallback:(void(^)(NSError *err))callback;

#pragma mark -
#pragma mark Getting style elements

/**
 * Return the style element for symbolic key.
 *
 * Note: Don't call unless |reload:| has been called at least once (which is
 *       implied by any of the class methods, but not init methods).
 */
- (KStyleElement*)styleElementForSymbol:(NSString const*)symbol;

@end
