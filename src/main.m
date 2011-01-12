// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.


#import <signal.h>

int main(int argc, char *argv[]) {
  sigset(SIGPIPE, (void(*)(int))&sigignore);
  return NSApplicationMain(argc,  (const char **) argv);
}
