#import "KStyle.h"
#import "KThread.h"
#import "KConfig.h"

NSString const * KStyleDidChangeNotification = @"KStyleDidChangeNotification";

static lwc_string *kBodyLWCString;

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
  //DLOG("css_node_has_name(pw, '%@', '%@') -> %@",
  //     [NSString stringWithLWCString:node],
  //     [NSString stringWithLWCString:name],
  //     match ? @"YES" : @"NO");
	return CSS_OK;
}

static css_error css_node_has_class(void *pw, void *n, lwc_string *name,
                                    bool *match) {
	*match = false;
	return CSS_OK;
}

static css_error css_parent_node(void *pw, void *n, void **parent) {
  lwc_string *node = (lwc_string *)n;
  bool isBodyNode = true;
  lwc_string_caseless_isequal(node, kBodyLWCString, &isBodyNode);
  if (!isBodyNode) {
    //DLOG("css_parent_node for '%@' -> 'body'",
    //     [NSString stringWithLWCString:node]);
    *parent = (void*)lwc_string_ref(kBodyLWCString);
  } else {
    *parent = NULL;
  }
	return CSS_OK;
}

static css_error ua_default_for_property(void *pw, uint32_t property,
                                         css_hint *hint) {
	if (property == CSS_PROP_COLOR) {
		hint->data.color = 0x111111ff;
		hint->status = CSS_BACKGROUND_COLOR_COLOR;
		//hint->status = CSS_COLOR_INHERIT;
	} else if (property == CSS_PROP_BACKGROUND_COLOR) {
		hint->data.color = 0xeeeeeeff;
		hint->status = CSS_COLOR_COLOR;
		//hint->status = CSS_COLOR_INHERIT;
	} else if (property == CSS_PROP_FONT_FAMILY) {
		hint->data.strings = NULL;
		hint->status = CSS_FONT_FAMILY_MONOSPACE;
    //hint->status = CSS_FONT_FAMILY_INHERIT;
	} else if (property == CSS_PROP_QUOTES) {
		hint->data.strings = NULL;
		hint->status = CSS_QUOTES_NONE;
	} else if (property == CSS_PROP_VOICE_FAMILY) {
		hint->data.strings = NULL;
		hint->status = 0;
	} else {
		return CSS_INVALID;
	}
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
static NSString const *gDefaultElementSymbol;

+ (void)load {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  
  // shared lwc_strings
  lwc_intern_string("body", 4, &kBodyLWCString);
  
  // instances
  gInstancesDict_ = [NSMutableDictionary new];
  gInstanceLoadQueueDict_ = [NSMutableDictionary new];

  // CSS select handler
  CSSSelectHandlerInitToBase(&gCSSHandler);
  gCSSHandler.node_name = &css_node_name;
  gCSSHandler.node_has_name = &css_node_has_name;
  gCSSHandler.node_has_class = &css_node_has_class;
  gCSSHandler.parent_node = &css_parent_node;
  gCSSHandler.ua_default_for_property = &ua_default_for_property;
  
  // Empty style
  gDefaultElementSymbol = [[@"body" internedString] retain];
  gEmptyStyle_ =
      [[KStyle alloc] initWithCatchAllElement:new KStyleElement(gDefaultElementSymbol)];
  
  [pool drain];
}


#pragma mark -
#pragma mark Getting shared instances


+ (KStyle*)emptyStyle {
  return gEmptyStyle_;
}


+ (CSSStylesheet*)baseStylesheet {
  HSemaphore::Scope dss(gBaseStylesheetSemaphore_);
  if (!gBaseStylesheet_) {
    NSData *data = [@"body { color:white; background-color:black; }"
                    dataUsingEncoding:NSUTF8StringEncoding];
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
  //DLOG("finalize key %@, style %@, err %@", key, style, err);
  NSMutableSet *callbacks;
  HSemaphoreSection(gInstancesSemaphore_) {
    if (style) {
      [gInstancesDict_ setObject:style forKey:key];
    }
    callbacks = [[gInstanceLoadQueueDict_ objectForKey:key] retain];
    [gInstanceLoadQueueDict_ removeObjectForKey:key];
  }
  
  // post KStyleDidChangeNotification before calling callbacks. This way code
  // inside the callback can register for the notification without receiving
  // a notification directly afterwards, which obvisouly indicate the same load
  // as the actual invocation of the callback.
  if (style) {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:KStyleDidChangeNotification object:style];
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
  //       runloops which sit and wait for I/O, but also to avoid spending
  //       precious time in the main thread, which would normally be the natural
  //       choice (depending on the complexity of the loaded CSS, considerable
  //       CPU cycles might be needed).
  //
  [url retain];
  [[KThread backgroundThread] performBlock:^{
    // shortcut to have the underlying NSURLConnection scheduled in the
    // backgroundThread (i.e. the callback will be invoked in that thread
    // -- the actual I/O is handled by a global Foundation-controlled thread).
    _loadStyle_load(url);
    [url release];
  }];
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
  [defaultStyle_ release];
  [super dealloc];
}


#pragma mark -
#pragma mark Getting style elements

/// Return the style element for symbolic key
- (KStyleElement*)styleElementForSymbol:(NSString const*)key {
  if (catchAllElement_) return catchAllElement_;
  
  OSSpinLockLock(&elementsSpinLock_);
  
  // assure the default element is loaded before continuing
  if (key != gDefaultElementSymbol) {
    if (elements_.get(key) == nil) {
      OSSpinLockUnlock(&elementsSpinLock_); // give lock to...
      [self defaultStyleElement];
      OSSpinLockLock(&elementsSpinLock_); // reaquire lock
    }
  }
  
  KStyleElement *elem = elements_.get(key);
  if (!elem) {
    lwc_string *elementName = [key LWCString];
    CSSStyle *style = nil;
    @try {
      style = [CSSStyle selectStyleForObject:elementName
                                   inContext:cssContext_
                               pseudoElement:0
                                       media:CSS_MEDIA_SCREEN
                                 inlineStyle:nil
                                usingHandler:&gCSSHandler];
      if (key == gDefaultElementSymbol) {
        // save CSSStyle for default element ("body")
        defaultStyle_ = [style retain];
      } else {
        // inherit style from default element ("body")
        kassert(defaultStyle_);
        style = [defaultStyle_ mergeWith:style];
      }
    } @catch (NSException *e) {
      WLOG("CSSStyle select failed %@ -- %@", e, [e callStackSymbols]);
      DLOG("cssContext_ => %@", cssContext_);
      DLOG("elementName => %@", key);
    }
    if (elementName)
      lwc_string_unref(elementName);
    elem = new KStyleElement(key, style);
    elements_.put(key, elem);
  }
  OSSpinLockUnlock(&elementsSpinLock_);

  return elem;
}


- (KStyleElement*)defaultStyleElement {
  return [self styleElementForSymbol:gDefaultElementSymbol];
}


#pragma mark -
#pragma mark Etc


- (NSString*)description {
  return [NSString stringWithFormat:@"<%@@%p %@>",
      NSStringFromClass([self class]), self, cssContext_];
}


@end


@implementation NSMutableAttributedString (KStyle)

- (void)setAttributesFromKStyle:(KStyle*)style range:(NSRange)range {
  NSAttributedStringEnumerationOptions opts = 0;
  //opts = NSAttributedStringEnumerationLongestEffectiveRangeNotRequired;
  [self enumerateAttribute:KStyleElementAttributeName
                   inRange:range
                   options:opts
                usingBlock:^(id value, NSRange range, BOOL *stop) {
    NSString const *symbol = value;
    
    // clear any formatter attributes (so we can perform "add" later, without
    // disrupting other attributes)
    KStyleElement::clearAttributes(self, range);
    
    // find current formatter for |elem|
    KStyleElement* formatter = [style styleElementForSymbol:symbol];
    
    // apply the formatters' style to |range|
    if (formatter)
      formatter->applyAttributes(self, range);
  }];
}

@end
