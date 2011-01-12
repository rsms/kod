// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "shared-dispatch-queues.h"

dispatch_queue_t gDispatchQueueSyntaxHighlight = NULL;

__attribute__((constructor(0))) static void __init() {
  gDispatchQueueSyntaxHighlight =
      dispatch_queue_create("kod.syntaxhighlight", NULL);
}

