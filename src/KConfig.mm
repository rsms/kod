#import "KConfig.h"
#import "common.h"

KConfiguration KConfig;
KConfiguration const *KConfiguration::instance_ = NULL;

KConfiguration::KConfiguration() {
  assert(KConfiguration::instance_ == NULL);
  KConfiguration::instance_ = this;
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  
  bundle = [[NSBundle mainBundle] retain];
  assert(bundle);
  resourceURL_ = [[bundle resourceURL] retain];
  assert(resourceURL_);
  
  defaults = [[NSUserDefaults standardUserDefaults] retain];
  assert(defaults);

  [pool drain];
}


KConfiguration::~KConfiguration() {
  [defaults synchronize];
}


NSColor* KConfiguration::getColor(NSString* key, NSColor* def) const {
  NSColor *v = [NSColor colorWithSRGBHexString:[defaults stringForKey:key]];
  return v ? v : def;
}


NSURL* KConfiguration::resourceURL(NSString* relpath) {
  return relpath ? [resourceURL_ URLByAppendingPathComponent:relpath]
                 : resourceURL_;
}

