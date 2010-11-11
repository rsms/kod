class KStyleElement;

/**
 * Represents a style (e.g. default.css)
 */
@interface KStyle : NSObject {
  NSString *name_;
  NSString *file_;

  /// Contains KStyleElement mapped by their string symbols.
  NSMapTable *elements_;
}

@property(readonly, nonatomic) NSString *name;
@property(readonly, nonatomic) NSString *file;

#pragma mark -
#pragma mark Getting shared instances

/// Retrieve a named shared style
+ (KStyle*)styleWithName:(NSString*)name error:(NSError**)outError;

/// Retrieve the default style (the users' current default style)
+ (KStyle*)defaultStyle;

#pragma mark -
#pragma mark Search paths
//
// Note: Paths are searched back-to-front, meaning the later a patch was added,
//       the higher priority it has.
//
// Note: searchPaths is initialized to contain standards paths.
//

/// Directories to search for named styles
+ (NSArray*)searchPaths;
+ (void)setSearchPaths:(NSArray*)path;

/// Prepend |path| to |searchPaths|, moving it to front if already added. 
+ (void)addSearchPath:(NSString*)path;

#pragma mark -
#pragma mark Initialization and deallocation

- (id)initWithName:(NSString*)name referencingFile:(NSString*)file;

#pragma mark -
#pragma mark Setting up elements

/// Reload from underlying file (this is an atomic operation)
- (BOOL)reload:(NSError**)outError;

#pragma mark -
#pragma mark Getting style elements

/**
 * Return the style element for symbolic key.
 *
 * Note: Don't call unless |reload:| has been called at least once (which is
 *       implied by any of the class methods, but not init methods).
 */
- (KStyleElement*)styleElementForKey:(NSString*)key;

@end
