#import "KLangMapLinePattern.h"
#import "HSpinLock.h"

// Language info struct
@interface KLangInfo : NSObject { // TODO: add archiving support
 @public
  NSURL *fileURL; // Definition file url (e.g. "file://.../cpp.lang")
  NSString *name; // Human-readable name (e.g. "C++")
}
- (id)initWithFileURL:(NSURL*)url name:(NSString*)name;
@end


/**
 * Maps filename extensions, names and line patterns to language definition
 * files.
 */
@interface KLangMap : NSObject {
 @public ///< XXX only during debug/dev
  // Directories to search for language definition files
  NSMutableArray *searchPaths_;
  HSpinLock searchPathsLock_;

  // Maps langId to URL (e.g. @"makefile" => KLangInfo<...>)
  NSMutableDictionary *langIdToInfo_;
  HSpinLock langIdToInfoLock_;

  // Maps UTI to langId (e.g. "public.c-header" => @"cpp")
  // TODO: langId should be a UTI in the future
  NSMutableDictionary *UTIToLangIdMap_;
  HSpinLock UTIToLangIdMapLock_;

  // List of patterns -- tested on first line of files -- mapping to langId's
  // (e.g. [ KLangMapLinePattern{pattern => "^<html", langId => @"html"}, .. ])
  NSMutableArray *firstLinePatternList_;
  HSpinLock firstLinePatternListLock_;

  // Maps she-bang program to langId (e.g. "#!/bin/sh" => @"bash")
  NSMutableDictionary *programToLangIdMap_;
  HSpinLock programToLangIdMapLock_;

  // Maps filename to langId (e.g. "Makefile" => @"makefile")
  NSMutableDictionary *nameToLangIdMap_;
  HSpinLock nameToLangIdMapLock_;

  // Maps extension to langId (e.g. "cc" => @"cpp")
  NSMutableDictionary *extToLangIdMap_;
  HSpinLock extToLangIdMapLock_;
}

@property(readonly) NSMutableArray *searchPaths;

/// Shared instance
+ (KLangMap const *)sharedLangMap;

/**
 * Retrieve the most suiting language id for source |filename| including
 * testing |firstLine| for matches in |firstLinePatternList_|. Returns nil if
 * none match.
 *
 * Search order priority:
 *
 * 1. UTI
 * 2. First line "she-bang" program
 * 3. First line regexp match
 * 4. Case-sensitive filename
 * 5. Case-sensitive extension
 * 5.2. Case-insensitive extension
 * 6. Case-insensitive filename
 *
 */
- (NSString const*)langIdForSourceURL:(NSURL*)url
                              withUTI:(NSString*)uti
                 consideringFirstLine:(NSString*)firstLine;

/// Retrieve info for language with id |langId| or nil if not found.
- (KLangInfo*)langInfoForLangId:(NSString*)langId;

/// Retrieve URL of language definition file for |langId| or nil if not found.
- (NSURL*)langFileURLForLangId:(NSString*)langId;

/// Convenience combo of langIdForSourceURL... and langFileURLForLangId:.
//- (NSURL*)langFileURLForSourceURL:(NSURL*)url
//             consideringFirstLine:(NSString*)firstLine;

/// Scan file at URL
- (BOOL)scanFileAtURL:(NSURL*)url
     inAllocationZone:(NSZone*)zone
                error:(NSError**)outError;

/// Asynchronously scan all language definition files found in |searchPaths|.
- (void)rescanWithCallback:(void(^)(NSError*))callback;


@end
