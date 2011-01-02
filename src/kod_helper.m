#import <getopt.h>
#import <err.h>

#import "kod_version.h"
#import "KMachServiceProtocol.h"
#import "common.h"

NSConnection *gConnection = nil;


static NSPort *openSharedKodMachPort() {
  return [[NSMachBootstrapServer sharedInstance]
      portForName:K_SHARED_SERVICE_PORT_NAME host:nil];
}


static id setupConnectionAndProxyObject(NSPort *sendPort) {
  id proxy;
  @try {
    gConnection = [[NSConnection alloc] initWithReceivePort:
        (NSPort*)[[sendPort class] port] sendPort:sendPort];
    proxy = [gConnection rootProxy];
  } @catch (NSException *e) {
    proxy = nil;
  }
  if (proxy)
    [proxy setProtocolForProxy:@protocol(KMachServiceProtocol)];
  return proxy;
}


static void printUsage(int exitStatus) {
  NSString *msg = [NSString stringWithFormat:
      @"usage: %@ [options] [<file-or-url> ..]\n"
       "options:\n"
       //"  -a --async        Don't wait for Kod.app to launch. Has no effect if\n"
       //"                    <file-or-url> arguments are passed.\n"
       "  --kod-app <path>  Communicate with Kod.app at <path>.\n"
       "  -h --help         Display this help message and exit.\n"
       "  --version         Display version info and exit.\n",
      [[NSProcessInfo processInfo] processName]];
  fprintf(stderr, "%s\n", [msg UTF8String]);
  if (exitStatus > -1)
    exit(exitStatus);
}


static NSURL *gKodAppURL = nil;
static NSMutableArray *gURLsToOpen = nil;


static void parseOptions(int argc, char *argv[]) {
  /*
  struct option {
    // name of long option
    const char *name;
    // one of no_argument, required_argument, and optional_argument:
    // whether option takes an argument
    int has_arg;
    // if not NULL, set *flag to val when option found
    int *flag;
    // if flag not NULL, value to set *flag to; else return value
    int val;
  };
  */
  static struct option long_options[] = {
    {"kod-app", required_argument, 0, 0},
    {"version", no_argument, 0, 0},
    {"help", no_argument, 0, 0},
    {0, 0, 0, 0}
  };
  static const char *short_options = "ah";

  int c;

  while (1) {
    int option_index = 0;
    c = getopt_long(argc, argv, short_options, long_options, &option_index);
    if (c == -1)
      break;
    switch (c) {
      case 0: {
        const char *optname = long_options[option_index].name;
        if (strcmp(optname, "help") == 0) {
          printUsage(123);
        } else if (strcmp(optname, "version") == 0) {
          fprintf(stderr, "kod version %s\n", K_VERSION_STR);
          exit(0);
        } else if (strcmp(optname, "kod-app") == 0) {
          NSString *path = [NSString stringWithUTF8String:optarg];
          gKodAppURL = [NSURL fileURLWithPath:path isDirectory:YES];
        }
        break;
      }
      case '?':
        printUsage(1);
        break;
      default:
        printUsage(123);
    }
  }

  // remaining arguments are paths or URLs
  if (optind < argc) {
    gURLsToOpen = [NSMutableArray arrayWithCapacity:argc-optind];
    while (optind < argc) {
      NSString *url = [NSString stringWithUTF8String:argv[optind++]];
      if ([url rangeOfString:@":"].location == NSNotFound) {
        url = [[[NSURL fileURLWithPath:url] absoluteURL] path];
      }
      [gURLsToOpen addObject:url];
    }
  }
}


static NSRunningApplication *findKodAppAndStartIfNeeded(BOOL asyncLaunch) {
  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];

  // find url for Kod.app
  if (!gKodAppURL) {
    gKodAppURL =
        [workspace URLForApplicationWithBundleIdentifier:@"se.hunch.kod"];
    if (!gKodAppURL)
      errx(1, "Unable to find Kod.app -- have you installed Kod?");
  }

  // launch kod
  NSWorkspaceLaunchOptions launchOptions = 0;
  if (asyncLaunch)
    launchOptions = NSWorkspaceLaunchAsync;
  NSArray *args = [NSArray arrayWithObject:@"--launched-from-kod-helper"];
  NSDictionary *confDict = [NSDictionary dictionaryWithObjectsAndKeys:
      args, NSWorkspaceLaunchConfigurationArguments,
      nil];
  NSError *error;
  NSRunningApplication *kodApp = [workspace launchApplicationAtURL:gKodAppURL
                                                           options:launchOptions
                                                     configuration:confDict
                                                             error:&error];
  if (!kodApp) {
    errx(1, "failed to launch Kod.app (%s)", [[error description] UTF8String]);
  }
  return kodApp;
}



int main(int argc, char *argv[]) {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  // parse command line arguments
  parseOptions(argc, argv);

  // make sure kod is launched, or launch kod and block until launched
  NSRunningApplication *kodApp = findKodAppAndStartIfNeeded(NO);

  // open named send port
  NSPort *sendPort;
  while (!(sendPort = openSharedKodMachPort())) {
    usleep(50000); // 50 ms
  }

  // create connection and proxy object
  id kodService = setupConnectionAndProxyObject(sendPort);
  if (!kodService) {
    WLOG("failed to establish a proxy object");
    exit(1);
  }
  DLOG("connected to %@ through %@", sendPort, kodService);

  // ask Kod.app to open any URLs passed on the command line
  if (gURLsToOpen)
    [kodService openURLs:gURLsToOpen];

  // close connection
  [gConnection invalidate];
  [gConnection release];
  gConnection = nil;

  _exit(0);
}
