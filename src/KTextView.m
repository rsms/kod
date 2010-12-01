#import "KTextView.h"

@implementation KTextView


// text container rect adjustments
static NSSize kTextContainerInset = (NSSize){6.0, 4.0}; // {(LR),(TB)}
static CGFloat kTextContainerXOffset = -8.0;
static CGFloat kTextContainerYOffset = 0.0;


- (id)initWithFrame:(NSRect)frame {
  if ((self = [super initWithFrame:frame])) {
    [self setAllowsUndo:YES];
    [self setAutomaticLinkDetectionEnabled:NO];
    [self setSmartInsertDeleteEnabled:NO];
    [self setAutomaticQuoteSubstitutionEnabled:NO];
    [self setAllowsDocumentBackgroundColorChange:NO];
    [self setAllowsImageEditing:NO];
    [self setRichText:NO];
    [self setImportsGraphics:NO];
    [self turnOffKerning:self]; // we are monospace (robot voice)
    [self setAutoresizingMask:NSViewWidthSizable];
    [self setUsesFindPanel:YES];
    [self setTextContainerInset:NSMakeSize(2.0, 4.0)];
    [self setVerticallyResizable:YES];
    [self setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    
    // TODO: the following settings should follow the current style
    [self setBackgroundColor:
        [NSColor colorWithCalibratedWhite:0.1 alpha:1.0]];
    [self setTextColor:[NSColor whiteColor]];
    [self setInsertionPointColor:
        [NSColor colorWithCalibratedRed:1.0 green:0.2 blue:0.1 alpha:1.0]];
    [self setSelectedTextAttributes:[NSDictionary dictionaryWithObject:
        [NSColor colorWithCalibratedRed:0.12 green:0.18 blue:0.27 alpha:1.0]
        forKey:NSBackgroundColorAttributeName]];

    // later adjusted by textContainerOrigin
    [self setTextContainerInset:kTextContainerInset];
  }
  return self;
}


- (NSPoint)textContainerOrigin {
  NSPoint origin = [super textContainerOrigin];
  origin.x += kTextContainerXOffset;
  origin.y += kTextContainerYOffset;
  return origin;
}


@end
