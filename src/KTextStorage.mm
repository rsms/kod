#import "KTextStorage.h"
#import "common.h"

@implementation KTextStorage


- (id)init {
  self = [super init];
  batchQueue_ = [[NSMutableArray alloc] init];
  return self;
}


- (void)dealloc {
  [batchQueue_ release];
  [super dealloc];
}


- (void)queueAttributes:(NSDictionary*)attrs range:(NSRange)range {
  HSpinLock::Scope sl_scope(batchQueueLock_);
  [batchQueue_ addObject:attrs];
  [batchQueue_ addObject:[NSValue valueWithRange:range]];
}


- (void)flushQueuedAttributes {
  NSMutableArray *newBatchQueue = [[NSMutableArray alloc] init];
  NSMutableArray *batchQueue = h_objc_swap(&batchQueue_, newBatchQueue);

  NSUInteger i, count = batchQueue.count;
  for (i = 0; i < count; i += 2) {
    NSDictionary *attrs = [batchQueue objectAtIndex:i];
    NSRange range = [[batchQueue objectAtIndex:i+1] rangeValue];
    [self setAttributes:attrs range:range];
  }

  [batchQueue release];
}


@end
