#import "common.h"

#import "KLangMap.h"
#import "KConfig.h"
#import <libkern/OSAtomic.h>


static NSError *kio_iterdir_foreach(NSURL *dirURL,
                                    BOOL(^entryHandler)(NSError**,NSURL*),
                                    NSArray *prefetchKeys = nil,
                                    NSDirectoryEnumerationOptions options =
                                      NSDirectoryEnumerationSkipsHiddenFiles) {
  NSFileManager *fm = [NSFileManager defaultManager];
  __block NSError *error = nil;
  NSDirectoryEnumerator *en =
            [fm enumeratorAtURL:dirURL
     includingPropertiesForKeys:prefetchKeys
                        options:options
                   errorHandler:^(NSURL *url, NSError *err) {
    if (!entryHandler(&err, url)) {
      error = err;
      return NO;
    }
    return YES;
  }];
  for (NSURL *url in en) {
    NSError *err = nil;
    if (!entryHandler(&err, url)) {
      error = err;
      break;
    }
  }
  return error;
}


static void kio_iterdirs_async(NSArray *dirs,
                               BOOL(^entryHandler)(NSError**,NSURL*),
                               void(^callback)(NSError*)=NULL) {
  // copy to avoid race cond: count vs actual
  assert(dirs);
  dirs = [dirs copy];
  assert(dirs.count <= INT32_MAX);
  __block int32_t countdown = dirs.count;
  if (countdown == 0) {
    callback(nil);
    [dirs release];
    return;
  }
  
  // dispatch queue
  dispatch_queue_t queue = dispatch_get_global_queue(0,0);
  
  // retain handler and callback
  __block BOOL(^_entryHandler)(NSError**,NSURL*) = [entryHandler copy];
  if (callback) callback = [callback copy];
  Class NSURLClass = [NSURL class];
  
  // dispatch each operation
  [dirs retain]; //< we need to retain this for some reason
  for (NSURL *dirURL_ in dirs) {
    dispatch_async(queue, ^{
      NSAutoreleasePool *pool = [NSAutoreleasePool new];
      // scan directory
      // convert path string to URL if neccessary
      NSURL *dirURL = dirURL_;
      if (![dirURL isKindOfClass:NSURLClass]) {
        assert([dirURL isKindOfClass:[NSString class]]);
        dirURL = [NSURL fileURLWithPath:(NSString*)dirURL];
      }
      if (!entryHandler) {
        // chain was aborted by an error
        [pool drain];
        return;
      }
      // synchronous readdir (deep)
      NSError *error = kio_iterdir_foreach(dirURL, _entryHandler);
      // decrement countdown
      uint32_t n = OSAtomicDecrement32(&countdown);
      // if we hit an error and we aren't the last job to finish...
      if (error && n != 0) {
        // ...cmpxch countdown to 0
        if (OSAtomicCompareAndSwap32(n, 0, &countdown)) {
          // we know that we "got number zero"
          n = 0;
        }
      }
      if (n == 0) {
        // we are the last job finishing (or we are responsible for aborting
        // due to an error)
        if (callback) {
          callback(error);
          [callback release];
        }
        [h_objc_swap((id volatile*)&_entryHandler, nil) release];
        [dirs release];
      }
      [pool drain];
    });
  }
  [dirs release];
}


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

static KLangMap const *gKLangMap = nil;
static HSpinLock gKLangMapSpinLock; // used by +sharedLangMap

+ (void)load {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  // FIXME: cache results in KConfig and "watch" URLs in searchPaths_ and
  // langIdToInfo_ for changes and scan only those files which change.
  KLangMap *langMap = [KLangMap sharedLangMap];
  [langMap rescanWithCallback:^(NSError *err){
    if (err) DLOG("error while rescanning lang dirs: %@", err);
    else DLOG("rescanned lang dirs");
    //DLOG("searchPaths_ => %@", langMap->searchPaths_);
    //DLOG("langIdToInfo_ => %@", langMap->langIdToInfo_);
    /*DLOG("UTIToLangIdMap_ => %@", langMap->UTIToLangIdMap_);
    DLOG("firstLinePatternList_ => %@", langMap->firstLinePatternList_);
    DLOG("nameToLangIdMap_ => %@", langMap->nameToLangIdMap_);
    DLOG("extToLangIdMap_ => %@", langMap->extToLangIdMap_);*/
    #if 0
    NSLog(@"searchPaths_ => %@", langMap->searchPaths_);
    NSLog(@"langIdToInfo_ => %@", langMap->langIdToInfo_);
    NSLog(@"UTIToLangIdMap_ => %@", langMap->UTIToLangIdMap_);
    NSLog(@"firstLinePatternList_ => %@", langMap->firstLinePatternList_);
    NSLog(@"nameToLangIdMap_ => %@", langMap->nameToLangIdMap_);
    NSLog(@"extToLangIdMap_ => %@", langMap->extToLangIdMap_);
    #endif
  }];

  [pool drain];
}


+ (KLangMap const *)sharedLangMap {
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
  firstLinePatternList_ = [NSMutableArray new];
  return self;
}


- (void) dealloc {
  [langIdToInfo_ release];
  [UTIToLangIdMap_ release];
  [extToLangIdMap_ release];
  [nameToLangIdMap_ release];
  [firstLinePatternList_ release];
  [super dealloc];
}


- (NSArray*)searchPaths {
  HSpinLock::Scope slscope(searchPathsLock_);
  if (searchPaths_) return searchPaths_;
  
  // users' paths take precedence
  static NSString *const configKey = @"langSearchPaths";
  NSArray *userDirnames = KConfig.getArray(configKey);
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
  [searchPaths_ addObject:KConfig.resourcePath(@"lang")];
  
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


- (NSString const*)langIdForSourceURL:(NSURL*)url
                              withUTI:(NSString*)uti
                 consideringFirstLine:(NSString*)firstLine {
  /*
   * Search order priority:
   *
   * 1. UTI
   * 2. First line match
   * 3. Case-sensitive filename
   * 4. Case-sensitive extension
   * 5. Case-insensitive extension
   */
  NSString *langId = nil;
  
  // 1. UTI
  if (uti) {
    UTIToLangIdMapLock_.lock();
    langId = [UTIToLangIdMap_ objectForKey:uti];
    UTIToLangIdMapLock_.unlock();
    if (langId) return langId;
  }
  
  // 2. First line
  if (firstLine) {
    for (KLangMapLinePattern *pattern in firstLinePatternList_) {
      // todo: test agains firstLine
    }
  }
  
  // The rest of the tests involve |url| -- bail unless non-nil
  if (!url) return nil;
  
  // 3. Complete filename ("basename"), case-sensitive
  NSString *name = [url lastPathComponent];
  nameToLangIdMapLock_.lock();
  langId = [nameToLangIdMap_ objectForKey:name];
  nameToLangIdMapLock_.unlock();
  if (langId) return langId;
  
  // 4. Filename extension
  NSString *ext = [name pathExtension];
  if (ext.length) {
    extToLangIdMapLock_.lock();
    // case-sensitive
    langId = [extToLangIdMap_ objectForKey:ext];
    // case-insensitive
    if (!langId)
      langId = [extToLangIdMap_ objectForKey:[ext lowercaseString]];
    extToLangIdMapLock_.unlock();
    if (langId) return langId;
  }
  
  return nil;
}


- (BOOL)scanFileAtURL:(NSURL*)url
     inAllocationZone:(NSZone*)zone
                error:(NSError**)outError {
  // TODO: Post notifications when things change OR implement KVO
  
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
  #define MATCH_EXT 1
  #define MATCH_UTI 2
  #define MATCH_NAME 3
  #define MATCH_FIRSTLINE 4
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
          SKIP_UNTIL_WHITESPACE_OR_NEWLINE;
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
        } else if (matchlen == 10 && strncmp(startp, "firstline", 9) == 0) {
          match = MATCH_FIRSTLINE;
        } else {
          continue;
        }
        
        // we got a match
        
        // register match
        if (match == MATCH_EXT || match == MATCH_UTI || match == MATCH_NAME) {
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
                extToLangIdMapLock_.unlock();
              } else if (match == MATCH_UTI) {
                UTIToLangIdMapLock_.lock();
                [UTIToLangIdMap_ setObject:ident forKey:s];
                UTIToLangIdMapLock_.unlock();
              } else {
                nameToLangIdMapLock_.lock();
                [nameToLangIdMap_ setObject:ident forKey:s];
                nameToLangIdMapLock_.unlock();
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
  kio_iterdirs_async(self.searchPaths, ^(NSError **ioerr, NSURL *url) {
    if (*ioerr)
      return NO; // abort on errors
    return [self scanFileAtURL:url inAllocationZone:zone error:ioerr];
  }, callback);
}



@end
