// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

@interface KPopUp : NSWindow {
  BOOL closesWhenResignsKey_;
  BOOL animatesAppearance_;
  BOOL isClosing_;
  NSRect originalFrame_; // stored during animation
  void(^onClose_)(KPopUp*);
}

@property BOOL closesWhenResignsKey,
               escapeKeyTriggersClose,
               animatesAppearance;

@property(copy) void(^onClose)(KPopUp*);

+ (KPopUp*)popupWithSize:(NSSize)size centeredInWindow:(NSWindow*)parentWindow;

- (id)initWithSize:(NSSize)size centeredInWindow:(NSWindow*)parentWindow;
- (id)initWithContentRect:(NSRect)contentRect;

@end
