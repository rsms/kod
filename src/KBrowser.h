// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import <ChromiumTabs/ChromiumTabs.h>

// We provide our own CTBrowser subclass so we can create our own, custom tabs.
// See the implementation file for details.

@interface KBrowser : CTBrowser {
  BOOL shouldCloseTab;
}

@end
