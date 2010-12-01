#import "KStyle.h"
#import "KThread.h"
#import "KConfig.h"

NSString const *KStyleWillChangeNotification = @"KStyleWillChangeNotification";
NSString const *KStyleDidChangeNotification = @"KStyleDidChangeNotification";

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

static css_select_handler gCSSHandler;

static CSSStylesheet* gBaseStylesheet_ = nil;
static HSemaphore gBaseStylesheetSemaphore_(1);

static KStyle *gSharedStyle_ = nil;
static NSString const *gDefaultElementSymbol;

+ (void)load {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  
  // shared lwc_strings
  lwc_intern_string("body", 4, &kBodyLWCString);

  // CSS select handler
  CSSSelectHandlerInitToBase(&gCSSHandler);
  gCSSHandler.node_name = &css_node_name;
  gCSSHandler.node_has_name = &css_node_has_name;
  gCSSHandler.node_has_class = &css_node_has_class;
  gCSSHandler.parent_node = &css_parent_node;
  gCSSHandler.ua_default_for_property = &ua_default_for_property;
  
  // Base element symbol
  gDefaultElementSymbol = [[@"body" internedString] retain];

  // The shared style is empty by default
  gSharedStyle_ = [[KStyle alloc] initWithCatchAllElement:
    new KStyleElement(gDefaultElementSymbol)];
  
  // Note: Loading of the default stylesheet is done by KAppDelegate in main()
  //       branch.
  
  [pool drain];
}


#pragma mark -
#pragma mark Getting shared instances


+ (KStyle*)sharedStyle {
  return gSharedStyle_;
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


/*+ (void)defaultStyleWithCallback:(void(^)(NSError*,KStyle*))callback {
  NSURL* url = KConfig.getURL(@"defaultStyleURL",
                              KConfig.resourceURL(@"style/default.css"));
  [self styleAtURL:url withCallback:callback];
}*/


#pragma mark -
#pragma mark Initialization and deallocation


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
#pragma mark Properties


- (NSURL*)url {
  if (cssContext_) {
    NSUInteger numStylesheets = [cssContext_ count];
    if (numStylesheets != 0) {
      CSSStylesheet *lastStylesheet =
          [cssContext_ stylesheetAtIndex:numStylesheets-1];
      return lastStylesheet.url;
    }
  }
  return nil;
}


#pragma mark -
#pragma mark Loading


- (void)_loadStylesheet:(NSURL*)url callback:(void(^)(NSError*))callback {
  // load stylesheet
  CSSStylesheet *stylesheet = [[CSSStylesheet alloc] initWithURL:url];
  BOOL started = [stylesheet loadFromRepresentedURLWithCallback:^(NSError *err) {
    // error loading URL?
    if (err) {
      [stylesheet release];
      if (callback) {
        callback(err);
        [callback release];
      }
      return;
    }
    
    // Get a ref to the lengthy named nc and post a "will" notification
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:KStyleWillChangeNotification object:self];
    
    // Setup a new CSS context
    // Is the baseStylesheet really needed?
    CSSContext* cssContext =
        [[CSSContext alloc] initWithStylesheet:[KStyle baseStylesheet]];
    [cssContext addStylesheet:stylesheet];
    kassert(cssContext);
    [stylesheet release]; // our local reference
    
    // Replace or set out cssContext_
    [h_objc_swap(&cssContext_, cssContext) release];
    
    // Clear any catchAllElement_
    KStyleElement *catchAll =
        (KStyleElement*)k_swapptr((void*volatile*)&catchAllElement_, NULL);
    if (catchAll)
      delete catchAll;

    // Empty cached elements
    OSSpinLockLock(&elementsSpinLock_);
    elements_.clear();
    OSSpinLockUnlock(&elementsSpinLock_);

    // post KStyleDidChangeNotification before calling callback. This way code
    // inside the callback can register for the notification without receiving
    // a notification directly afterwards, which obvisouly indicate the same load
    // as the actual invocation of the callback.
    [nc postNotificationName:KStyleDidChangeNotification object:self];

    // invoke callback
    if (callback) {
      callback(err);
      [callback release];
    }
  }];
  
  // URL connection failed to start?
  if (!started) {
    [stylesheet release];
    if (callback) {
      callback([NSError kodErrorWithFormat:@"Failed to open URL %@", url]);
      [callback release];
    }
  }
}


- (void)loadFromURL:(NSURL*)url withCallback:(void(^)(NSError*))callback {
  // retain the callback
  if (callback)
    callback = [callback copy];
  
  // Defer loading to background
  //
  // Note: We do this in order to avoid many lingering threads just running
  //       runloops which sit and wait for I/O (we might get called on a
  //       temporary "dispatch queue" thread), but also to avoid spending
  //       precious time in the main thread, which would normally be the natural
  //       choice (depending on the complexity of the loaded CSS, considerable
  //       CPU cycles might be needed).
  //
  [url retain];
  [[KThread backgroundThread] performBlock:^{
    // shortcut to have the underlying NSURLConnection scheduled in the
    // backgroundThread (i.e. the callback will be invoked in that thread
    // -- the actual I/O is handled by a global Foundation-controlled thread).
    [self _loadStylesheet:url callback:callback];
    [url release];
  }];
}


- (void)reloadWithCallback:(void(^)(NSError*))callback {
  NSURL *url = self.url;
  if (url) {
    [self loadFromURL:url withCallback:callback];
  } else if (callback) {
    callback([NSError kodErrorWithFormat:
        @"No URL to reload -- style is not backed by an external source"]);
  }
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
