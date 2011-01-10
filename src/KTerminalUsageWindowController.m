#import "common.h"
#import "kconf.h"
#import "KSudo.h"
#import "KTerminalUsageWindowController.h"

@implementation KTerminalUsageWindowController



- (NSString*)_canonicalizePath:(NSString*)path isDirectory:(BOOL)isDir {
  path = [path stringByExpandingTildeInPath];
  return [[[NSURL fileURLWithPath:path isDirectory:isDir] absoluteURL] path];
}


- (void)awakeFromNib {
  static NSString * const possiblePaths[] = {
    @"~/bin",
    @"/usr/local/bin",
    @"/usr/bin",
    @"/bin",
    nil
  };

  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *possiblePath;
  NSUInteger i = 0;
  NSString *homeDir = [NSHomeDirectory() stringByAppendingString:@"/"];
  NSString *binPath = [kconf_url(@"cli/symlink/url", nil) path];

  if (binPath) {
    binPath = [binPath stringByDeletingLastPathComponent];
  } else {
    while ((possiblePath = possiblePaths[i++])) {
      possiblePath = [self _canonicalizePath:possiblePath isDirectory:YES];
      BOOL isDir;
      if ([fm fileExistsAtPath:possiblePath isDirectory:&isDir] && isDir) {
        binPath = possiblePath;
        break;
      }
    }
  }

  if (binPath) {
    if (binPath.length == homeDir.length-1 &&  [homeDir hasPrefix:binPath]) {
      // case: binPath="/Users/john", homeDir="/Users/john/"
      binPath = @"~";
    } else if ([binPath hasPrefix:homeDir]) {
      // case: binPath="/users/john/foo/bin", homeDir="/Users/john/"
      binPath = [@"~/" stringByAppendingString:
                 [binPath substringFromIndex:homeDir.length]];
    }
    [binPathTextField_ setStringValue:binPath];
  }
}


- (IBAction)createLink:(id)sender {
  DLOG("%@ createLink:%@", self, sender);
  NSFileManager *fm = [NSFileManager defaultManager];
  NSBundle *bundle = kconf_bundle();

  // build dst path
  NSString *dstPath = [kconf_support_url(@"kod") path];
  kassert([fm fileExistsAtPath:dstPath]);

  NSString *binPath = [binPathTextField_ stringValue];
  binPath = [self _canonicalizePath:binPath isDirectory:YES];

  // check link path
  NSError *error = nil;
  BOOL isDir;
  if (!binPath) {
    error = [NSError kodErrorWithFormat:@"Invalid or empty path. Please enter "
                                         "an absolute and valid path."];
  } else if (![fm fileExistsAtPath:binPath isDirectory:&isDir]) {
    error = [NSError kodErrorWithFormat:@"The directory '%@' does not exist",
             binPath];
  } else if (!isDir) {
    error = [NSError kodErrorWithFormat:@"The file '%@' is not a directory",
             binPath];
  }
  if (error) {
    [NSApp presentError:error];
    return;
  }

  // build link path
  NSString *linkPath = [binPath stringByAppendingPathComponent:@"kod"];

  // remove existing file if found
  NSString *existingLinkDst = [fm destinationOfSymbolicLinkAtPath:linkPath
                                                            error:nil];
  if (existingLinkDst) {
    existingLinkDst = [self _canonicalizePath:existingLinkDst isDirectory:NO];
    if ([existingLinkDst isEqualToString:linkPath]) {
      // already same link
      [self close];
      return;
    } else {
      error = [NSError kodErrorWithFormat:@"Another file exists at '%@' -- "
              "please remove that file and try again or chose another location",
              linkPath];
      [NSApp presentError:error];
      return;
    }
  }

  // need sudo to write?
  if (![fm isWritableFileAtPath:binPath]) {
    [binPathTextField_ setEnabled:NO];
    [cancelButton_ setEnabled:NO];
    [commitButton_ setEnabled:NO];
    WLOG("sudo /bin/ln -fs '%@' '%@'", dstPath, linkPath);
    [KSudo execute:@"/bin/ln"
         arguments:[NSArray arrayWithObjects:@"-fs", dstPath, linkPath, nil]
          callback:^(NSError *err, NSData *output){
      [binPathTextField_ setEnabled:YES];
      [cancelButton_ setEnabled:YES];
      [commitButton_ setEnabled:YES];
      if (err) {
        NSInteger authCancelledOSError = -60006; // subject to endian bug?!
        if (![[err domain] isEqualToString:NSOSStatusErrorDomain] ||
            [err code] != authCancelledOSError) {
          DLOG("failed to execute ln as root: %@", err);
          [NSApp presentError:err];
        } else {
          DLOG("authorization request aborted by user");
        }
      } else {
        kconf_set_url(@"cli/symlink/url", [NSURL fileURLWithPath:linkPath]);
        DLOG("sudo ln appear to have succeeded (we currently are unable to test"
             " return status, but are working on it)");
        [self close];
      }
    }];
  } else {
    // create symbolic link
    BOOL createLink = [fm createSymbolicLinkAtPath:linkPath
                               withDestinationPath:dstPath
                                             error:&error];
    if (!createLink) {
      DLOG("error: %@", error);
      [NSApp presentError:error];
    } else {
      kconf_set_url(@"cli/symlink/url", [NSURL fileURLWithPath:linkPath]);
      [self close];
    }
  }
}


@end
