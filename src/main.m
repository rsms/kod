#import <signal.h>

int main(int argc, char *argv[]) {
  sigset(SIGPIPE, (void(*)(int))&sigignore);
  return NSApplicationMain(argc,  (const char **)argv);
}
