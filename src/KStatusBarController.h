// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "KStatusBarView.h"
@class KSplitView, KDocument;

extern NSString * const KStatusBarDidChangeHiddenStateNotification;

@interface KStatusBarController : NSViewController {
  IBOutlet KSplitView *splitView_;
  IBOutlet NSButton *toggleSplitViewButton_;
  KDocument *currentContents_;
}

@property(readonly) KStatusBarView *statusBarView;
@property(nonatomic) BOOL isHidden;

- (void)updateWithContents:(KDocument*)contents;

- (IBAction)toggleSplitView:(id)sender;
- (IBAction)toggleStatusBarVisibility:(id)sender;

@end
