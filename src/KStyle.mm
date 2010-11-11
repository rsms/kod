#import "KStyle.h"
#import "KStyleElement.h"

#import <libkern/OSAtomic.h>

@implementation KStyle

@synthesize name = name_,
            file = file_;

#pragma mark -
#pragma mark Module construction

static NSMutableDictionary *gInstancesDict_;
static dispatch_semaphore_t gInstancesSemaphore_; // 1/0 = unlocked/locked

static NSMutableArray *gSearchPaths_;
static dispatch_semaphore_t gSearchPathsSemaphore_; // 1/0 = unlocked/locked


+ (void)load {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  
  // instances
  NSMutableDictionary *gInstancesDict_ = [NSMutableDictionary new];
  gInstancesSemaphore_ = dispatch_semaphore_create(1);

  // search paths
  NSBundle *mainBundle = [NSBundle mainBundle];
  NSString *builtinStyleDir = nil;
  if (mainBundle && mainBundle.resourcePath) {
    builtinStyleDir =
        [mainBundle.resourcePath stringByAppendingPathComponent:@"style"];
  }
  gSearchPaths_ = [[NSMutableArray alloc] initWithObjects:builtinStyleDir, nil];
  gSearchPathsSemaphore_ = dispatch_semaphore_create(1);

  [pool drain];
}


#pragma mark -
#pragma mark Getting shared instances

+ (KStyle*)styleWithName:(NSString*)name error:(NSError**)outError {
  KSemaphoreScope dss(gInstancesSemaphore_);
  KStyle *style = [gInstancesDict_ objectForKey:name];
  if (!style) {
    name = [name internedString];
    NSString *file = nil; // TODO
    style = [[self alloc] initWithName:name referencingFile:file];
    if ([style reload:outError]) {
      [gInstancesDict_ setObject:style forKey:name];
      [style release];
    } else {
      [style release];
      style = nil;
    }
  }
  return style;
}


+ (KStyle*)defaultStyle {
  // TODO: load name from user defaults
  NSError *error;
  KStyle *style = [self styleWithName:@"default" error:&error];
  if (!style)  // is this really a nice API ?
    [NSApp presentError:error];
  return style;
}


#pragma mark -
#pragma mark Search paths


/// Directories to search for named styles
+ (NSArray*)searchPaths {
  KSemaphoreScope dss(gSearchPathsSemaphore_);
  return [NSArray arrayWithArray:gSearchPaths_];
}

+ (void)setSearchPaths:(NSArray*)paths {
  KSemaphoreScope dss(gSearchPathsSemaphore_);
  [gSearchPaths_ replaceObjectsInRange:NSMakeRange(0, gSearchPaths_.count)
                  withObjectsFromArray:paths];
}

/// Prepend |path| to |searchPaths|, moving it to front if already added. 
+ (void)addSearchPath:(NSString*)path {
  KSemaphoreScope dss(gSearchPathsSemaphore_);
  [gSearchPaths_ removeObject:path];
  [gSearchPaths_ addObject:path];
}


#pragma mark -
#pragma mark Initialization and deallocation

// internal helper function for creating a new NSMapTable for elements_
static inline NSMapTable *
_newElementsMapTableWithInitialCapacity(NSUInteger capacity) {
  NSMapTable *table = [NSMapTable alloc];
  return [table initWithKeyOptions:NSMapTableObjectPointerPersonality
                      valueOptions:NSMapTableStrongMemory
                          capacity:1];
}

static inline void _freeElementsMapTable(NSMapTable **elements) {
  // NSMapTable does not manage refcounting so we need to release contents
  // before releasing the NSMapTable itself.
  for (id element in *elements) {
    [element release];
  }
  [*elements release];
  *elements = NULL;
}


- (id)initWithName:(NSString*)name referencingFile:(NSString*)file {
  self = [self init];
  name_ = [name retain];
  file_ = [file retain];
  elements_ = nil;
  return self;
}


- (void)dealloc {
  [name_ release];
  [file_ release];
  _freeElementsMapTable(&elements_);
  [super dealloc];
}


#pragma mark -
#pragma mark Setting up elements

/// Reload from underlying file (this is an atomic operation)
- (BOOL)reload:(NSError**)outError {
  // TODO: read file_ -- on error, set outError and return NO

  // Create a new elements map
  NSMapTable *elements = _newElementsMapTableWithInitialCapacity(1);

  // TODO: create elements

  // Atomically exchange
  NSMapTable *old = h_objc_swap(&elements_, elements);
  if (old) _freeElementsMapTable(&old);

  // TODO: post notification "reloaded"
  
  return YES;
}


#pragma mark -
#pragma mark Getting style elements

/// Return the style element for symbolic key
- (KStyleElement*)styleElementForKey:(NSString*)key {
  return (KStyleElement*)[elements_ objectForKey:key];
}

@end
