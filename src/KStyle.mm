#import "KStyle.h"
#import "KThread.h"
#import "KConfig.h"

NSString const * KStyleDidChangeNotification = @"KStyleDidChangeNotification";

// CSS select handler functions
static css_error css_node_name(void *pw, void *n, lwc_string **name) {
	lwc_string *node = (lwc_string *)n;
	*name = lwc_string_ref(node);
	return CSS_OK;
}
static css_error css_node_has_name(void *pw, void *n, lwc_string *name,
                                   bool *match) {
	lwc_string *node = (lwc_string *)n;
	assert(lwc_string_caseless_isequal(node, name, match) == lwc_error_ok);
	return CSS_OK;
}
static css_error css_node_has_class(void *pw, void *n, lwc_string *name,
                                    bool *match) {
	*match = false;
	return CSS_OK;
}


@implementation KStyle

#pragma mark -
#pragma mark Module construction

static NSMutableDictionary *gInstancesDict_; // [urlstr => KStyle]
static NSMutableDictionary *gInstanceLoadQueueDict_; // [urlstr => block]
static HSemaphore gInstancesSemaphore_(1); // 1/0 = unlocked/locked

static css_select_handler gCSSHandler;

static CSSStylesheet* gBaseStylesheet_ = nil;
static HSemaphore gBaseStylesheetSemaphore_(1);

static KStyle *gEmptyStyle_ = nil;

+ (void)load {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  
  // instances
  gInstancesDict_ = [NSMutableDictionary new];
  gInstanceLoadQueueDict_ = [NSMutableDictionary new];

  // CSS select handler
  CSSSelectHandlerInitToBase(&gCSSHandler);
  gCSSHandler.node_name = &css_node_name;
  gCSSHandler.node_has_name = &css_node_has_name;
  gCSSHandler.node_has_class = &css_node_has_class;
  
  // Empty style
  gEmptyStyle_ =
      [[KStyle alloc] initWithCatchAllElement:new KStyleElement(@"normal")];
  
  [pool drain];
}


#pragma mark -
#pragma mark Getting shared instances


+ (KStyle*)emptyStyle {
  return gEmptyStyle_;
}


+ (CSSStylesheet*)baseStylesheet {
  // Maybe: in the future, this should be a computed with regards to the current
  // editor background color.
  HSemaphore::Scope dss(gBaseStylesheetSemaphore_);
  if (!gBaseStylesheet_) {
    NSData *data = [@"body { color:#fff; }" dataUsingEncoding:NSUTF8StringEncoding];
    gBaseStylesheet_ = [[CSSStylesheet alloc] initWithURL:nil];
    __block NSError *error = nil;
    [gBaseStylesheet_ loadData:data withCallback:^(NSError *err) {
      error = err;
    }];
    // since there are no imports, callback is not deferred
    if (error) {
      [gBaseStylesheet_ release];
      gBaseStylesheet_ = nil;
      [NSApp presentError:error];
    }
  }
  return gBaseStylesheet_;
}


static void _loadStyle_finalize(NSString const *key, KStyle *style,
                                NSError* err) {
  DLOG("finalize key %@, style %@, err %@", key, style, err);
  NSMutableSet *callbacks;
  HSemaphoreSection(gInstancesSemaphore_) {
    if (style) {
      [gInstancesDict_ setObject:style forKey:key];
    }
    callbacks = [[gInstanceLoadQueueDict_ objectForKey:key] retain];
    [gInstanceLoadQueueDict_ removeObjectForKey:key];
  }
  
  // invoke queued callbacks
  if (callbacks) {
    for (KStyleLoadCallback callback in callbacks) {
      callback(err, style);
    }
    [callbacks release]; // implies releasing of callbacks
  }
}


static void _loadStyle_load(NSURL* url) {
//static void _loadStyle_load(void *data) { NSURL* url=(NSURL*)data;
  // load stylesheet
  CSSStylesheet *stylesheet = [[CSSStylesheet alloc] initWithURL:url];
  BOOL started = [stylesheet loadFromRepresentedURLWithCallback:^(NSError *err) {
    // retrieve key symbol
    NSString const *key = [[url absoluteString] internedString];
    
    // error loading URL?
    if (err) {
      [stylesheet release];
      _loadStyle_finalize(key, nil, err);
      return;
    }
    
    // Setup a new CSS context
    CSSContext* cssContext =
        [[CSSContext alloc] initWithStylesheet:[KStyle baseStylesheet]];
    [cssContext addStylesheet:stylesheet];
    assert(cssContext);
    [stylesheet release]; // our local reference
    
    // Create a new KStyle with the CSS context
    KStyle *style = [[KStyle alloc] initWithCSSContext:cssContext];
    assert(style);
    [cssContext release]; // our local reference
    
    // finalize -- register style and call all queued callbacks
    _loadStyle_finalize(key, style, nil);
  }];
  
  if (!started) {
    [stylesheet release];
    NSString const *key = [[url absoluteString] internedString];
    NSError *err = [NSError kodErrorWithFormat:
      @"Internal error: Failed to create URL connection for URL %@", url];
    _loadStyle_finalize(key, nil, err);
  }
}


static void _loadStyle(NSURL* url) {
  //
  // Defer loading to background
  //
  // Note: We do this in order to avoid many lingering threads just running
  //       runloops which sit and wait for I/O.
  //
  [url retain];
  [[KThread backgroundThread] performBlock:^{
    _loadStyle_load(url);
    [url release];
  }];
  /*dispatch_async_f(dispatch_get_global_queue(0,0),
                   [url retain],  ///< or it might get autoreleased before used
                   &_loadStyle_load);*/
}


+ (void)styleAtURL:(NSURL*)url
      withCallback:(void(^)(NSError*,KStyle*))callback {
  assert(callback != 0);
  // scoped critical section
  HSemaphore::Scope dss(gInstancesSemaphore_);
  
  // key for global dicts
  NSString *key = [url absoluteString];
  
  // see if we already have a cached style
  KStyle *style = [gInstancesDict_ objectForKey:key];
  if (style) {
    // ok, style is already loaded –- return immediately.
    callback(nil, style);
    return;
  }

  // add callback to load queue
  callback = [callback copy];
  assert(gInstanceLoadQueueDict_ != nil);
  NSMutableSet *callbacks = [gInstanceLoadQueueDict_ objectForKey:key];
  if (callbacks) {
    // a load operation is already in-flight -- queue callback for invocation
    [callbacks addObject:callback];
    [callback release];
    return;
  }
  
  // we are first -- create queue and add ourselves to it
  callbacks = [NSMutableSet setWithObject:callback];
  [callback release];
  [gInstanceLoadQueueDict_ setObject:callbacks forKey:key];
  
  // trigger loading of URL
  _loadStyle(url);
}


+ (void)defaultStyleWithCallback:(void(^)(NSError*,KStyle*))callback {
  NSURL* url = KConfig.getURL(@"defaultStyleURL",
                              KConfig.resourceURL(@"style/default.css"));
  [self styleAtURL:url withCallback:callback];
}


#pragma mark -
#pragma mark Initialization and deallocation

// internal helper function for creating a new NSMapTable for elements_
/*static inline CFMutableDictionaryRef *
_newElementsMapWithInitialCapacity(NSUInteger capacity) {
  NSMapTable *table = [NSMapTable alloc];
  return [table initWithKeyOptions:NSMapTableObjectPointerPersonality
                      valueOptions:NSMapTableStrongMemory
                          capacity:1];
}

static inline void _freeElementsMapTable(NSMapTable **elements) {
  // NSMapTable does not manage refcounting so we need to release contents
  // before releasing the NSMapTable itself.
  for (id element in *elements) {
    delete element;
  }
  [*elements release];
  *elements = NULL;
}*/


- (id)init {
  self = [super init];
  elementsSpinLock_ = OS_SPINLOCK_INIT;
  return self;
}


- (id)initWithCSSContext:(CSSContext*)cssContext {
  self = [self init];
  cssContext_ = [cssContext retain];
  return self;
}


- (id)initWithCatchAllElement:(KStyleElement*)element {
  self = [self init];
  catchAllElement_ = element;
  return self;
}


- (void)dealloc {
  [cssContext_ release];
  if (catchAllElement_) delete catchAllElement_;
  [super dealloc];
}


#pragma mark -
#pragma mark Getting style elements

/// Return the style element for symbolic key
- (KStyleElement*)styleElementForSymbol:(NSString const*)key {
  if (catchAllElement_) return catchAllElement_;
  OSSpinLockLock(&elementsSpinLock_);
  KStyleElement *elem = elements_.get(key);
  if (!elem) {
    lwc_string *elementName = [key LWCString];
    CSSStyle *style = [CSSStyle selectStyleForObject:elementName
                                           inContext:cssContext_
                                       pseudoElement:0
                                               media:CSS_MEDIA_SCREEN
                                         inlineStyle:nil
                                        usingHandler:&gCSSHandler];
    lwc_string_unref(elementName);
    elem = new KStyleElement(key);
    
    NSColor *color = style.color;
    if (!color) {
      //color = KConfig.getColor(@"defaultTextColor", [NSColor whiteColor]);
      // random color
      srand((unsigned)(pointer_t)key);
      CGFloat hue = (CGFloat)rand() / RAND_MAX;
      color = [NSColor colorWithCalibratedHue:hue saturation:0.5 brightness:0.9 alpha:1.0];
    }
    elem->setForegroundColor(color);
    
    elements_.put(key, elem);
  }
  OSSpinLockUnlock(&elementsSpinLock_);

  return elem;
}


#pragma mark -
#pragma mark Formatting


- (void)applyStyle:(NSString const*)typeSymbol
        toMAString:(NSMutableAttributedString*)mastr
           inRange:(NSRange)range
    //withAttributes:(NSDictionary*)extraAttrs
     byReplacement:(BOOL)replace {
  // lookup style element for element type
  KStyleElement *element = [self styleElementForSymbol:typeSymbol];
  NSDictionary *attrs = nil;

  // Set text attributes
  if (element) {
    NSDictionary *attrs = element->textAttributes();
    /*if (extraAttrs) {
      attrs = [attrs ]
    }*/
    [mastr setAttributes:attrs range:range];
    //[currentMAString_ addAttributes:element->textAttributes() range:range];
    // Note: setAttributes is faster than addAttributes, but it replaces _any_
    // attribute.
  } else {
    KStyleElement::clearAttributes(mastr, range, true);
  }
  #if 0
  DLOG("%@ applyStyle:%@ %@ '%@' <-- %@", typeSymbol,
             NSStringFromRange(range),
             [mastr.string substringWithRange:range],
             element ? element->textAttributes() : nil);
  #endif
}


- (void)applyStyleToMAString:(NSMutableAttributedString*)mastr {
  NSRange textRange = NSMakeRange(0, mastr.length);
  NSAttributedStringEnumerationOptions opts = 0;
  //opts = NSAttributedStringEnumerationLongestEffectiveRangeNotRequired;
  [mastr enumerateAttribute:KStyleElement::ClassAttributeName
                    inRange:textRange
                    options:opts
                 usingBlock:^(id value, NSRange range, BOOL *stop) {
    NSString const *symbol = value;
    
    // clear any formatter attributes
    KStyleElement::clearAttributes(mastr, range);
    // find current formatter for |elem|
    KStyleElement* formatter = [self styleElementForSymbol:symbol];
    // apply the formatters' style to |range|
    if (formatter) {
      formatter->applyAttributes(mastr, range);
    }
    //DLOG("%s %@", elem.c_str(), NSStringFromRange(range));
  }];
}


@end
