#import "HSpinLock.h"

@interface KTextStorage : NSTextStorage {
  NSMutableArray *batchQueue_;
  HSpinLock batchQueueLock_;
}

- (void)queueAttributes:(NSDictionary*)attrs range:(NSRange)range;
- (void)flushQueuedAttributes;

@end
