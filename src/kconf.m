#import "kconf.h"
#import "HEventEmitter.h"
#import "NSColor-web.h"

NSString * const KConfValueDidChangeNotification =
    @"KConfValueDidChangeNotification";

static inline NSURL *_relurl(NSURL *baseurl, NSString *relpath) {
  return relpath ? [baseurl URLByAppendingPathComponent:relpath] : baseurl;
}


NSURL* kconf_res_url(NSString* relpath) {
  return _relurl([kconf_bundle() resourceURL], relpath);
}


NSURL* kconf_support_url(NSString* relpath) {
  return _relurl([kconf_bundle() sharedSupportURL], relpath);
}


void kconf_notify_change(NSString *key) {
  [kconf_defaults() post:KConfValueDidChangeNotification
              userObject:key
                  forKey:@"key"];
}


NSURL* kconf_url(NSString* key, NSURL* def) {
  NSString *v = [kconf_defaults() stringForKey:key];
  if (!v) {
    return def;
  } else if ([v rangeOfString:@":"].location == NSNotFound) {
    if (![v hasPrefix:@"/"])
      v = [v stringByStandardizingPath];
    return [NSURL fileURLWithPath:v];
  } else {
    return [NSURL URLWithString:v];
  }
}


NSColor* kconf_color(NSString* key, NSColor* def) {
  id v = [kconf_defaults() stringForKey:key];
  if (v) v = [NSColor colorWithSRGBHexString:v];
  return v ? v : def;
}

void kconf_set_color(NSString* key, NSColor* v) {
  if (v) [kconf_defaults() setObject:[v sRGBhexString] forKey:key];
  else [kconf_defaults() removeObjectForKey:key];
}

