#import "shared-dispatch-queues.h"

dispatch_queue_t gDispatchQueueSyntaxHighlight = NULL;

__attribute__((constructor(0))) static void __init() {
  gDispatchQueueSyntaxHighlight =
      dispatch_queue_create("kod.syntaxhighlight", NULL);
}

