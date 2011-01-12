// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

@class KASTViewerController;

@interface KASTViewerWindowController : NSWindowController {
  IBOutlet KASTViewerController* outlineViewController_;
}

@property(assign) KASTViewerController* outlineViewController;

+ (KASTViewerWindowController*)sharedInstance;

@end
