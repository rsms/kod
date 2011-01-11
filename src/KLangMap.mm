#import "common.h"

#import "KLangMap.h"
#import "kconf.h"
#import "kfs.h"
#import "ICUPattern.h"
#import "ICUMatcher.h"
#import <libkern/OSAtomic.h>


@implementation KLangInfo
- (id)initWithFileURL:(NSURL*)url name:(NSString*)_name {
  self = [super init];
  fileURL = [url retain];
  name = [_name retain];
  return self;
}
- (void)dealloc {
  [fileURL release];
  [name release];
  [super dealloc];
}
- (NSString*)description {
  return [NSString stringWithFormat:@"<%@@%p {'%@', %@}>",
      NSStringFromClass([self class]), self, name, fileURL];
}
@end


@implementation KLangMap

static KLangMap *gKLangMap = nil;
static HSpinLock gKLangMapSpinLock; // used by +sharedLangMap

// Shared regular expressions
static ICUPattern *gSheBangDirectRegExp;
static ICUPattern *gSheBangEnvRegExp;

+ (void)load {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  // Shared regular expressions
  // '#! /usr/bin/env perl'
  gSheBangEnvRegExp = [[ICUPattern alloc] initWithString:
  @"#[[:blank:]]*![[:blank:]]*(?:[\\./]*)(?:[[:alnum:]]+[\\./]+)*(?:env)[[:blank:]]+([[:alnum:]]+)"
                                              flags:ICUCaseInsensitiveMatching];
  assert(gSheBangEnvRegExp != nil);
  // '#! /usr/bin/perl'
  gSheBangDirectRegExp = [[ICUPattern alloc] initWithString:
  @"#[[:blank:]]*![[:blank:]]*(?:[\\./]*)(?:[[:alnum:]]+[\\./]+)*([[:alnum:]]+)"
                                              flags:ICUCaseInsensitiveMatching];
  assert(gSheBangDirectRegExp != nil);

  [pool drain];
}


+ (KLangMap*)sharedLangMap {
  HSpinLock::Scope slscope(gKLangMapSpinLock);
  if (!gKLangMap) {
    gKLangMap = [[KLangMap alloc] init];
  }
  return gKLangMap;
}


- (id)init {
  self = [super init];
  langIdToInfo_ = [NSMutableDictionary new];
  UTIToLangIdMap_ = [NSMutableDictionary new];
  extToLangIdMap_ = [NSMutableDictionary new];
  nameToLangIdMap_ = [NSMutableDictionary new];
  programToLangIdMap_ = [NSMutableDictionary new];
  firstLinePatternList_ = [NSMutableArray new];
  return self;
}


- (void) dealloc {
  [langIdToInfo_ release];
  [UTIToLangIdMap_ release];
  [extToLangIdMap_ release];
  [nameToLangIdMap_ release];
  [programToLangIdMap_ release];
  [firstLinePatternList_ release];
  [super dealloc];
}


- (NSArray*)searchPaths {
  HSpinLock::Scope slscope(searchPathsLock_);
  if (searchPaths_) return searchPaths_;

  // users' paths take precedence
  static NSString *const configKey = @"langSearchPaths";
  NSArray *userDirnames = kconf_array(configKey, nil);
  if (userDirnames) {
    searchPaths_ = [[NSMutableArray alloc] initWithCapacity:userDirnames.count];
    Class NSURLClass = [NSURL class];
    Class NSStringClass = [NSString class];
    for (NSURL *entry in userDirnames) {
      if ([entry isKindOfClass:NSURLClass]) {
        [searchPaths_ addObject:[(NSURL*)entry absoluteURL]];
      } else if ([entry isKindOfClass:NSStringClass]) {
        entry =
          [NSURL fileURLWithPath:[(NSString*)entry stringByStandardizingPath]];
        [searchPaths_ addObject:entry];
      } // else ignore
    }
  } else {
    searchPaths_ = [[NSMutableArray alloc] initWithCapacity:1];
  }

  // Append the built-in lang dir
  [searchPaths_ addObject:[kconf_res_url(@"lang") path]];

  return searchPaths_;
}


- (KLangInfo*)langInfoForLangId:(NSString*)langId {
  HSpinLock::Scope slscope(langIdToInfoLock_);
  return [langIdToInfo_ objectForKey:langId];
}


- (NSURL*)langFileURLForLangId:(NSString*)langId {
  KLangInfo *info = [self langInfoForLangId:langId];
  return info ? info->fileURL : nil;
}


- (NSString*)langIdForSourceURL:(NSURL*)url
                        withUTI:(NSString*)uti
           consideringFirstLine:(NSString*)firstLine {
  /*
   * Search order priority:
   *
   * 1. UTI
   * 2. First line "she-bang" program
   * 3. First line regexp match
   * 4. Case-sensitive filename
   * 5. Case-sensitive extension
   * 6. Case-insensitive extension
   */
  NSString *langId = nil;

  // 1. UTI
  if (uti) {
    UTIToLangIdMapLock_.lock();
    langId = [UTIToLangIdMap_ objectForKey:uti];
    UTIToLangIdMapLock_.unlock();
    if (langId) return langId;
  }

  // Test on first line of content
  if (firstLine && firstLine.length) {
    ICUMatcher *m;

    // 2. She-bang program ('#! /usr/bin/env perl')
    NSString *program = nil;
    m = [ICUMatcher matcherWithPattern:gSheBangEnvRegExp overString:firstLine];
    if ([m findNext]) {
      assert([m numberOfGroups] > 0);
      program = [m groupAtIndex:1];
    } else {
      // Try direct program name, e.g. '#! /usr/bin/perl'
      [m setPattern:gSheBangDirectRegExp];
      [gSheBangDirectRegExp setStringToSearch:firstLine];
      if ([m findNext]) {
        assert([m numberOfGroups] > 0);
        program = [m groupAtIndex:1];
      }
    }
    if (program) {
      programToLangIdMapLock_.lock();
      langId = [programToLangIdMap_ objectForKey:program];
      programToLangIdMapLock_.unlock();
      if (langId) return langId;
    }

    // 3. First line pattern
    HSpinLockSync(firstLinePatternListLock_) {
      for (KLangMapLinePattern *pattern in firstLinePatternList_) {
        assert(pattern->pattern != nil);
        [m setPattern:pattern->pattern];
        [pattern->pattern setStringToSearch:firstLine];
        //DLOG("test '%@' with '%@'", firstLine, pattern->pattern);
        if ([m findNext]) {
          return pattern->langId;
        }
      }
    }
  }

  // The rest of the tests involve |url| -- bail unless non-nil
  if (!url) return nil;

  // 4. Complete filename ("basename"), case-sensitive
  NSString *name = [url lastPathComponent];
  nameToLangIdMapLock_.lock();
  langId = [nameToLangIdMap_ objectForKey:name];
  nameToLangIdMapLock_.unlock();
  if (langId) return langId;

  // 5. Filename extension
  NSString *ext = [name pathExtension];
  if (ext.length) {
    extToLangIdMapLock_.lock();
    // 5.1. case-sensitive
    langId = [extToLangIdMap_ objectForKey:ext];
    // 5.2. case-insensitive
    if (!langId)
      langId = [extToLangIdMap_ objectForKey:[ext lowercaseString]];
    extToLangIdMapLock_.unlock();
    if (langId) return langId;
  }

  // 6. Complete filename ("basename"), case-insensitive
  nameToLangIdMapLock_.lock();
  langId = [nameToLangIdMap_ objectForKey:[name lowercaseString]];
  nameToLangIdMapLock_.unlock();
  if (langId) return langId;

  return nil;
}


- (BOOL)scanFileAtURL:(NSURL*)url
     inAllocationZone:(NSZone*)zone
                error:(NSError**)outError {
  // TODO: Post notifications when things change OR implement KVO
  // TODO: Replace this scanner with a Ragel machine

  // open file for reading
  NSString *pathstr = [url path];
  const char *path = [pathstr UTF8String];
  FILE *f = fopen(path, "r");
  if (!f) {
    *outError = [NSError kodErrorWithCode:errno
                           format:@"failed to open file \"%s\" for reading: %s",
                                  path, strerror(errno)];
    return NO; // abort
  }

  // register langId => URL
  NSString *ident = [[pathstr lastPathComponent] stringByDeletingPathExtension];
  ident = [ident internedString];
  KLangInfo *langInfo =
      [[KLangInfo allocWithZone:zone] initWithFileURL:url name:ident];
  langIdToInfoLock_.lock();
  [langIdToInfo_ setObject:langInfo forKey:ident];
  langIdToInfoLock_.unlock();
  [langInfo release];

  // read the first <=1024 bytes
  static const int bufz = 1024;
  char buf[bufz];
  BOOL pastWhitespaceLeading = NO;
  #define SKIP_PAST_WHITESPACE \
    for (; *p && (*p == ' ' || *p == '\t'); p++ )
  #define SKIP_UNTIL_WHITESPACE \
    for (; *p && (*p != ' ' && *p != '\t'); p++ )
  #define SKIP_UNTIL_WHITESPACE_OR_NEWLINE \
    for (; *p && (*p != ' ' && *p != '\t' && *p != '\n' && *p != '\r'); p++ )
  #define SKIP_UNTIL_NEWLINE \
    for (; *p && (*p != '\n' && *p != '\r'); p++ )
  #define MATCH_EXT 1
  #define MATCH_UTI 2
  #define MATCH_NAME 3
  #define MATCH_FIRSTLINE 4
  #define MATCH_PROGRAM 5
  // # @match
  while (fgets(buf, bufz, f) != NULL) {
    char *p = buf;
    // skip past leading space
    SKIP_PAST_WHITESPACE;
    // dig deeper if line starts with "#"
    if ( *p && (*p++ == '#') ) {
      if (!pastWhitespaceLeading)
        pastWhitespaceLeading = YES;
      // skip past space
      SKIP_PAST_WHITESPACE;
      // continue w/ next line unless it starts with "@"
      if ( !*p || (*p++ != '@'))
        continue;
      // dig deeper if line continues with "title"
      if (strncmp(p, "title", 5) == 0) {
        p += 5; // past "title"
        if (*p++ == ' ' || *p == '\t') {
          SKIP_PAST_WHITESPACE;
          char *startp = p;
          SKIP_UNTIL_NEWLINE;
          int matchlen = p-startp;
          if (matchlen) {
            langInfo->name = [[NSString allocWithZone:zone]
                              initWithBytes:startp
                                     length:matchlen
                                   encoding:NSUTF8StringEncoding];
          }
        }
      }
      // dig deeper if line continues with "@match"
      else if (strncmp(p, "match", 5) == 0) {
        p += 5;
        // skip until whitespace
        char *startp = p;
        SKIP_UNTIL_WHITESPACE;
        // skip past space
        SKIP_PAST_WHITESPACE;
        // cmd branch
        int match = 0, matchlen = p-startp;
        if (matchlen == 4 && strncmp(startp, "ext", 3) == 0) {
          match = MATCH_EXT;
        } else if (matchlen == 4 && strncmp(startp, "uti", 3) == 0) {
          match = MATCH_UTI;
        } else if (matchlen == 5 && strncmp(startp, "name", 4) == 0) {
          match = MATCH_NAME;
        } else if (matchlen == 8 && strncmp(startp, "program", 7) == 0) {
          match = MATCH_PROGRAM;
        } else if (matchlen == 10 && strncmp(startp, "firstline", 9) == 0) {
          match = MATCH_FIRSTLINE;
        } else {
          continue;
        }

        // we got a match

        // register match
        if (match == MATCH_EXT || match == MATCH_UTI || match == MATCH_NAME ||
            match == MATCH_PROGRAM) {
          while (*p && *p != '\n') { // for each component...
            startp = p;
            for (; *p && (*p != ',' && *p != '\n'); p++ );
            if (p-startp) {
              NSString *s = [[NSString allocWithZone:zone]
                              initWithBytes:startp
                                     length:p-startp
                                   encoding:NSUTF8StringEncoding];
              if (match == MATCH_EXT) {
                extToLangIdMapLock_.lock();
                [extToLangIdMap_ setObject:ident forKey:s];
                [extToLangIdMap_ setObject:ident forKey:[s lowercaseString]];
                extToLangIdMapLock_.unlock();
              } else if (match == MATCH_UTI) {
                UTIToLangIdMapLock_.lock();
                [UTIToLangIdMap_ setObject:ident forKey:s];
                UTIToLangIdMapLock_.unlock();
              } else if (match == MATCH_NAME) {
                nameToLangIdMapLock_.lock();
                [nameToLangIdMap_ setObject:ident forKey:s];
                [nameToLangIdMap_ setObject:ident forKey:[s lowercaseString]];
                nameToLangIdMapLock_.unlock();
              } else if (match == MATCH_PROGRAM) {
                programToLangIdMapLock_.lock();
                [programToLangIdMap_ setObject:ident forKey:s];
                programToLangIdMapLock_.unlock();
              }
              [s release];
            }
            if (*p) {
              p++; // past ","
              SKIP_PAST_WHITESPACE;
            }
          }
        } else if (match == MATCH_FIRSTLINE) {
          char *endp = p+(strlen(p)-1);
          if (*endp == '\n') *endp = '\0';
          NSString *s = [NSString stringWithUTF8String:p];
          KLangMapLinePattern *entry = [[KLangMapLinePattern allocWithZone:zone]
               initWithPattern:s langId:ident];
          firstLinePatternListLock_.lock();
          [firstLinePatternList_ addObject:entry];
          firstLinePatternListLock_.unlock();
          [entry release];
          //DLOG("regexp: '%@'", s);
        }

      }
    } else if ( (!*p || *p == '\n' || *p == '\r') && !pastWhitespaceLeading ) {
      pastWhitespaceLeading = YES;
    } else if (pastWhitespaceLeading) {
      // we are past whitespace leading and the line is not a comment
      break;
    }
  }
  fclose(f);

  return YES;
}


- (void)rescanWithCallback:(void(^)(NSError*))callback {
  NSZone *zone = [self zone];
  kfs_iterdirs_async(self.searchPaths, ^(NSError **ioerr, NSURL *url) {
    if (*ioerr) {
      // abort on error
      return NO;
    }
    if ([[url lastPathComponent] hasPrefix:@"_"]) {
      // don't scan "purely included" files
      return YES;
    }
    // scan file
    return [self scanFileAtURL:url inAllocationZone:zone error:ioerr];
  }, callback);
}



@end
