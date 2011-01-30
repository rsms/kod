// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

@interface NSEvent (kod)
// returns a 64-bit integer which uniquely represents this event in a
// device-independent fashion
- (uint64_t)kodHash;

// returns a string representation of the equivalent kod input binding sequence
// e.g. an event triggered by Cmd+R would return "M-S-r" (meta-shift-r)
- (NSString*)kodInputBindingDescription;
@end
