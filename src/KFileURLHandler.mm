#import "common.h"
#import "KTextView.h"
#import "KFileURLHandler.h"

#include <sys/xattr.h>

@implementation KFileURLHandler


- (BOOL)canReadURL:(NSURL*)url {
  return [url isFileURL];
}


- (void)_readXAttrsAtPath:(NSString*)path
            selectedRange:(NSRange*)selectedRange
             textEncoding:(NSStringEncoding*)textEncoding {
  // read xattrs
  *selectedRange = (NSRange){0,0};
  int fd = open([path UTF8String], O_RDONLY);
  if (fd < 0) {
    WLOG("failed to open(\"%@\", O_RDONLY)", path);
  } else {
    const char *key;
    ssize_t readsz;
    static size_t bufsize = 512;
    char *buf = (char*)malloc(sizeof(char)*bufsize);
    
    key = "com.apple.TextEncoding";
    // The value is a string "utf-8;134217984" where the last part (if
    // present) is a CFStringEncoding encoded in base-10.
    if ((readsz = fgetxattr(fd, key, (void*)buf, bufsize, 0, 0)) < 0) {
      DLOG("failed to read xattr '%s' from '%@'", key, path);
    } else if (readsz > 2) { // <2 chars doesnt make sense
      NSString *s = [[NSString alloc] initWithBytesNoCopy:(void*)buf
                                                   length:readsz
                                                 encoding:NSUTF8StringEncoding
                                             freeWhenDone:NO];
      NSRange r = [s rangeOfString:@";"];
      CFStringEncoding enc1 = 0;
      if (r.location != NSNotFound) {
        // try parsing a suffix integer value
        enc1 = [[s substringFromIndex:r.location+1] integerValue];
        NSStringEncoding enc2 =
            CFStringConvertEncodingToNSStringEncoding(enc1);
        if (enc2 < NSASCIIStringEncoding || enc2 > NSUTF32LittleEndianStringEncoding) {
          // that didn't work, lets set s to the first part and continue
          enc1 = -1;
          s = [s substringToIndex:r.location];
        }
      }
      if (enc1 == 0) {
        // try to parse s as an IANA charset (e.g. "utf-8")
        enc1 = CFStringConvertIANACharSetNameToEncoding((CFStringRef)s);
      }
      if (enc1 > 0) {
        *textEncoding = CFStringConvertEncodingToNSStringEncoding(enc1);
      }
      //DLOG("xattr read encoding '%@' %d -> %@ ([%d] %@)", s, (int)enc1,
      //     CFStringConvertEncodingToIANACharSetName(enc1),
      //     (int)textEncoding_,
      //     [NSString localizedNameOfStringEncoding:textEncoding_]);
    }
    
    key = "se.hunch.kod.selection";
    if ((readsz = fgetxattr(fd, key, (void*)buf, bufsize, 0, 0)) < 0) {
      DLOG("failed to read xattr '%s' from '%@'", key, path);
    } else if (readsz > 2) { // <2 chars doesnt make sense
      NSString *s = [[NSString alloc] initWithBytesNoCopy:(void*)buf
                                                   length:readsz
                                                 encoding:NSUTF8StringEncoding
                                             freeWhenDone:NO];
      *selectedRange = NSRangeFromString(s);
      DLOG("loaded selection from xattr: %@", s);
    }
    
    free(buf); buf = NULL;
    close(fd);
  }
}


- (NSData*)_readFileURL:(NSURL *)absoluteURL
                  inTab:(KTabContents*)tab
          selectedRange:(NSRange*)selectedRange
                  error:(NSError**)outError {
  // utilize mmap to load a file
  NSString *path = [absoluteURL path];
  NSData *data = [NSData dataWithContentsOfMappedFile:path];
  
  // if we failed to read the file, set outError with info
  if (!data) {
    if ([absoluteURL checkResourceIsReachableAndReturnError:outError]) {
      // reachable, but might be something else than a regular file
      NSFileManager *fm = [NSFileManager defaultManager];
      BOOL isDir;
      BOOL exists = [fm fileExistsAtPath:path isDirectory:&isDir];
      assert(exists == true); // since checkResourceIsReachableAndReturnError
      if (isDir) {
        *outError = [NSError kodErrorWithFormat:@"'%@' is a directory", path];
      } else {
        *outError = [NSError kodErrorWithFormat:@"Unknown I/O read error"];
      }
    }
    return nil;
  }
  
  // read xattrs
  NSStringEncoding textEncoding = -1;
  [self _readXAttrsAtPath:path
            selectedRange:selectedRange
             textEncoding:&textEncoding];
  if (textEncoding != -1)
    tab.textEncoding = textEncoding;

  // read mtime
  NSDate *mtime = nil;
  if (![absoluteURL getResourceValue:&mtime
                              forKey:NSURLContentModificationDateKey
                               error:outError]) {
    return nil;
  }
  tab.fileModificationDate = mtime;
  
  return data;
}


- (void)_readURL:(NSURL*)absoluteURL
          ofType:(NSString*)typeName
           inTab:(KTabContents*)tab
 successCallback:(void(^)(void))successCallback {
  NSError *error = nil;
  NSRange selectedRange;
  NSData *data = [self _readFileURL:absoluteURL
                              inTab:tab
                      selectedRange:&selectedRange
                              error:&error];

  if (!data) {
    [tab urlHandler:self finishedReadingURL:absoluteURL
               data:nil
             ofType:typeName
              error:error
           callback:nil];
  } else {
    [tab urlHandler:self finishedReadingURL:absoluteURL
               data:data
             ofType:typeName
              error:error
           callback:^(NSError *err){
      if (err) return;
      // restore (or set) selection
      KTextView *textView = tab.textView;
      if (selectedRange.location < textView.textStorage.length) {
        //DLOG("restoring selection to: %@", NSStringFromRange(selectedRange));
        [textView setSelectedRange:selectedRange];
      }
      if (successCallback)
        successCallback();
    }];
  }
}


- (void)readURL:(NSURL*)absoluteURL
         ofType:(NSString*)typeName
          inTab:(KTabContents*)tab
successCallback:(void(^)(void))successCallback {
  if ([NSThread isMainThread]) {
    // file I/O is blocking an thus we always read files on a background thread
    K_DISPATCH_BG_ASYNC({
      [self _readURL:absoluteURL ofType:typeName inTab:tab
       successCallback:successCallback];
    });
  } else {
    // already called on a background thread
    [self _readURL:absoluteURL ofType:typeName inTab:tab
     successCallback:successCallback];
  }
}


- (void)readURL:(NSURL*)absoluteURL
         ofType:(NSString*)typeName
          inTab:(KTabContents*)tab {
  [self readURL:absoluteURL
         ofType:typeName
          inTab:tab
successCallback:nil];
}


@end
