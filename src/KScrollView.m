#import "KScrollView.h"
#import "KScroller.h"

@implementation KScrollView

+ (Class)_verticalScrollerClass {
  //NSLog(@"KScrollView _verticalScrollerClass");
	return [KScroller class];
}

+ (Class)_horizontalScrollerClass {
  //NSLog(@"KScrollView _horizontalScrollerClass");
	return [KScroller class];
}

@end
