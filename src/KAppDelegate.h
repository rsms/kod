// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import <Cocoa/Cocoa.h>

@class SUUpdater, KTerminalUsageWindowController;

@interface KAppDelegate : NSObject <NSApplicationDelegate> {
  IBOutlet SUUpdater *sparkleUpdater_;
  KTerminalUsageWindowController *terminalUsageWindowController_;
}

- (IBAction)newWindow:(id)sender;
- (IBAction)newDocument:(id)sender;  // "New tab"
- (IBAction)displayTerminalUsage:(id)sender;
- (IBAction)displayAbout:(id)sender;

/*-(void)openDocumentInWindow:(KBrowserWindowController*)windowController
                     sender:(id)sender;*/

@end
