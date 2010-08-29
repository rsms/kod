#import "KToolbarController.h"

@implementation KToolbarController

- (void)updateToolbarWithContents:(CTTabContents*)contents
               shouldRestoreState:(BOOL)shouldRestore {
  // subclasses should implement this
}


// Called after the view is done loading and the outlets have been hooked up.
- (void)awakeFromNib {
}


@end
