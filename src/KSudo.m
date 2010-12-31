#import "common.h"
#import "kconf.h"
#import "KSudo.h"
#import "HDStream.h"
#import "HEventEmitter.h"

#import <Security/Authorization.h>
#import <Security/AuthorizationTags.h>


@implementation KSudo


+ (void)execute:(NSString*)executable
      arguments:(NSArray*)arguments
         prompt:(NSString*)prompt
       callback:(void(^)(NSError*,NSData*))callback {
  // canonicalize and resolve executable file
  const char *executablePch = [executable UTF8String];
  if (executablePch[0] != '/') {
    if (!(executablePch = kfs_which(executablePch))) {
      DLOG("%@: which '%@' failed", self, executable);
      callback([NSError kodErrorWithFormat:@"Executable file not found"], nil);
      return;
    }
    // utilize autorelease to release the string allocated by kfs_which
    [[[NSString alloc] initWithBytesNoCopy:(void*)executablePch
                                   length:strlen(executablePch)
                                 encoding:NSUTF8StringEncoding
                             freeWhenDone:YES] autorelease];
  } else if (!kfs_isexec(executablePch)) {
    DLOG("%@: %@ is not executable", self, executable);
    callback([NSError kodErrorWithFormat:@"Not an executable file"], nil);
    return;
  }

  executablePch = strdup(executablePch);

  // Setup authorization
  OSStatus status;
  AuthorizationRef authRef;
  AuthorizationEnvironment authEnv;
  AuthorizationItem authEnvItems[2];
  authEnv.items = authEnvItems;
  authEnv.count = 1;
  const char *iconPath = [[kconf_res_url(@"kod.icns") path] UTF8String];
  authEnvItems[0].name = kAuthorizationEnvironmentIcon;
  authEnvItems[0].valueLength = strlen(iconPath);
  authEnvItems[0].value = (void*)strdup(iconPath);
  authEnvItems[0].flags = 0;
  if (prompt) {
    authEnv.count = 2;
    const char *promptPch = [prompt UTF8String];
    authEnvItems[1].name = kAuthorizationEnvironmentPrompt;
    authEnvItems[1].valueLength = strlen(promptPch);
    authEnvItems[1].value = (void*)strdup(promptPch);
    authEnvItems[1].flags = 0;
  }

  // create auth object
  status = AuthorizationCreate(NULL, &authEnv, kAuthorizationFlagDefaults,
                               &authRef);
  if (status != errAuthorizationSuccess) {
    DLOG("%@: AuthorizationCreate failed", self);
    callback([NSError kodErrorWithOSStatus:status], nil);
    return;
  }

  // copy auth rights
  AuthorizationItem right = {kAuthorizationRightExecute, 0, NULL, 0};
  AuthorizationRights rightSet = { 1, &right };
  status = AuthorizationCopyRights(authRef, &rightSet, &authEnv,
                                   kAuthorizationFlagDefaults
                                   |kAuthorizationFlagPreAuthorize
                                   |kAuthorizationFlagInteractionAllowed
                                   |kAuthorizationFlagExtendRights,
                                   NULL);
  if (status != errAuthorizationSuccess) {
    DLOG("%@: AuthorizationCopyRights failed", self);
    AuthorizationFree(authRef, kAuthorizationFlagDestroyRights);
    callback([NSError kodErrorWithOSStatus:status], nil);
    return;
  }

  // create argv
  char **argv = NULL;
  if (arguments.count != 0) {
    argv = (char**)malloc(sizeof(void*)*arguments.count+1);
    NSUInteger i = 0;
    for (NSString *arg in arguments) {
      argv[i++] = (char*)strdup([[arg description] UTF8String]);
    }
    argv[i] = NULL;
  }

  // execute privileged program
  FILE *ioPipe;
  char buffer[4096];
  int bytesRead;
  status = AuthorizationExecuteWithPrivileges(authRef,
                                              executablePch,
                                              0, argv, &ioPipe);
  free(argv);
  if (status != errAuthorizationSuccess) {
    DLOG("%@: AuthorizationExecuteWithPrivileges failed", self);
    AuthorizationFree(authRef, kAuthorizationFlagDestroyRights);
    callback([NSError kodErrorWithOSStatus:status], nil);
    return;
  }

  // setup a duplex stream to gather stdout
  HDStream *stream = [HDStream streamWithFileDescriptor:fileno(ioPipe)];
  NSMutableData *data = [NSMutableData data];
  stream.onData = ^(const void *bytes, size_t length) {
    [data appendBytes:bytes length:length];
  };
  [stream on:@"close", ^(HDStream *stream){
    AuthorizationFree(authRef, kAuthorizationFlagDefaults);
    callback(nil, data);
  }];
  [stream resume];
}


+ (void)execute:(NSString*)executable
      arguments:(NSArray*)arguments
       callback:(void(^)(NSError*,NSData*))callback {
  [self execute:executable
      arguments:arguments
         prompt:nil
       callback:callback];
}


@end
