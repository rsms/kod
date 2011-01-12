// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.


@interface KTerminalUsageWindowController : NSWindowController {
  IBOutlet NSTextField *binPathTextField_;
  IBOutlet NSButton *cancelButton_;
  IBOutlet NSButton *commitButton_;
}

- (IBAction)createLink:(id)sender;

@end
