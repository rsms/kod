#import "HUnorderedMap.h"
#import "KStyleElement.h"

#import <libkern/OSAtomic.h>
#import <CSS/CSS.h>

@class KStyle;

extern NSString const * KStyleDidChangeNotification;
typedef void (^KStyleLoadCallback)(NSError*, KStyle*);

/**
 * Represents a style (e.g. default.css)
 */
@interface KStyle : NSObject {
  CSSContext* cssContext_;
  KStyleElement *catchAllElement_;
  
  // Style for default element ("body") used to create other elements
  CSSStyle *defaultStyle_;

  /// Contains KStyleElement mapped by their string symbols.
  HUnorderedMapSharedPtr<NSString const*, KStyleElement> elements_;
  OSSpinLock elementsSpinLock_;
  BOOL isLoading_;
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

/// Return the default element for this style ("body")
- (KStyleElement*)defaultStyleElement;


@end


@interface NSMutableAttributedString (KStyle)
- (void)setAttributesFromKStyle:(KStyle*)style range:(NSRange)range;
@end;
