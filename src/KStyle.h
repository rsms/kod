// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "HUnorderedMap.h"
#import "KStyleElement.h"

#import <libkern/OSAtomic.h>
#import <CSS/CSS.h>

#ifdef __cplusplus
#import "ASTNode.hh"
#endif

@class KStyle;

extern NSString * const KStyleDidChangeNotification;

/**
 * Represents a style (e.g. default.css)
 */
@interface KStyle : NSObject {
  CSSContext* cssContext_;

  // Style for default element ("body") used to create other elements
  CSSStyle *defaultStyle_;
  OSSpinLock styleSpinLock_;

  /// Contains KStyleElement mapped by their string symbols.
  HUnorderedMapSharedPtr<NSString const*, KStyleElement> elements_;
  OSSpinLock elementsSpinLock_;

  // Font
  NSFont* baseFont_;
}

/// Source url, or nil if not backed by an external source
@property(readonly) NSURL *url;
@property(readonly, nonatomic) NSFont* baseFont;
@property(readonly, nonatomic) NSFontDescriptor* baseFontDescriptor;
@property(readonly) CSSContext* cssContext;

#pragma mark -
#pragma mark Getting shared instances

/// The shared style
+ (KStyle*)sharedStyle;
+ (CSSStylesheet*)createBaseStylesheetWithData:(NSData*)data;
+ (CSSStylesheet*)baseStylesheet;

#pragma mark -
#pragma mark Initialization and deallocation

- (id)initWithCSSContext:(CSSContext*)cssContext;

#pragma mark -
#pragma mark Loading

/// Load from |url| calling optional |callback|
- (void)loadFromURL:(NSURL*)url withCallback:(void(^)(NSError *err))callback;

/// Reload from underlying source with optional |callback|
- (void)reloadWithCallback:(void(^)(NSError *err))callback;

/// Shorthand for reloadWithCallback:nil
- (void)reload;

#pragma mark -
#pragma mark Getting style elements

/// CSS style for element name (uncached)
- (CSSStyle*)styleForElementName:(NSString*)elementName;

/**
 * Return the style element for symbolic key.
 *
 * Note: Don't call unless |reload:| has been called at least once (which is
 *       implied by any of the class methods, but not init methods).
 */
- (KStyleElement*)styleElementForSymbol:(NSString*)symbol;

#ifdef __cplusplus
/// CSS style for an AST node
- (CSSStyle*)styleForASTNode:(kod::ASTNode*)astNode;
#endif

/// Return the default element for this style ("body")
@property(readonly) KStyleElement *defaultStyleElement;


@end


@interface NSMutableAttributedString (KStyle)
- (void)setAttributesFromKStyle:(KStyle*)style range:(NSRange)range;
@end;
