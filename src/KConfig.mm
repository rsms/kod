#import "KConfig.h"
#import "common.h"


KConfiguration KConfig;
KConfiguration const *KConfiguration::instance_ = NULL;

// we have moved constructor code into this method because KConfig is used
// in some _program constructors_ which might or might not execute before the
// stack-global instance's constructor is called.
void KConfiguration::init() {
  kassert(KConfiguration::instance_ == NULL); // must only be called once
  KConfiguration::instance_ = this;
  
  // use a scope mempool since we can get called from wherever
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  
  bundle = [[NSBundle mainBundle] retain];
  kassert(bundle);
  resourceURL_ = [[[bundle resourceURL] absoluteURL] retain];
  kassert(resourceURL_);
  
  defaults = [[NSUserDefaults standardUserDefaults] retain];
  kassert(defaults);

  [pool drain];
}

KConfiguration::KConfiguration() {
  if (!instance_) init();
}

KConfiguration::~KConfiguration() {
  [defaults synchronize];
}


NSColor* KConfiguration::getColor(NSString* key, NSColor* def) {
  if (!instance_) init();
  NSColor *v = [NSColor colorWithSRGBHexString:[defaults stringForKey:key]];
  return v ? v : def;
}


NSURL* KConfiguration::resourceURL(NSString* relpath) {
  if (!instance_) init();
  return relpath ? [resourceURL_ URLByAppendingPathComponent:relpath]
                 : resourceURL_;
}


NSString* KConfiguration::resourcePath(NSString* relpath) {
  return relpath ? [resourceURL(relpath) path] : [resourceURL_ path];
}


NSString* KConfiguration::supportPath(NSString* relpath) {
  NSString *sharedSupportPath = [bundle sharedSupportPath];
  return relpath ? [sharedSupportPath stringByAppendingPathComponent:relpath]
                 : sharedSupportPath;
}
