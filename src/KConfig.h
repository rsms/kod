/**
 * Kod configuration
 */
class KConfiguration {
 public:
  KConfiguration();
  ~KConfiguration();
  void init();

  NSBundle*        bundle;
  NSUserDefaults*  defaults;
  NSString*        builtinLangDir;
  NSURL*           resourceURL_;

  // defaults getters
  BOOL          getBool(NSString* key);
  int           getInt(NSString* key);
  float         getFloat(NSString* key);
  double        getDouble(NSString* key);
  NSArray*      getArray(NSString* key, NSArray* def=nil);
  NSArray*      getStrings(NSString* key, NSArray* def=nil);
  NSData*       getData(NSString* key, NSData* def=nil);
  NSDictionary* getDict(NSString* key, NSDictionary* def=nil);
  NSString*     getString(NSString* key, NSString* def=nil);
  NSURL*        getURL(NSString* key, NSURL* def=nil);
  NSColor*      getColor(NSString* key, NSColor* def=nil);
  id            get(NSString* key, id def=nil);
  inline id operator[] (NSString* key) { return get(key); }

  // defaults setters
  void set(NSString* key, BOOL v);
  void set(NSString* key, int v);
  void set(NSString* key, float v);
  void set(NSString* key, double v);
  void set(NSString* key, NSURL* v);
  void set(NSString* key, NSColor* v);
  void set(NSString* key, id v);
  inline void remove(NSString* key) { [defaults removeObjectForKey:key]; }

  // resources
  NSURL* resourceURL(NSString* relpath);
  NSString* resourcePath(NSString* relpath);

 protected:
  static KConfiguration const *instance_;
};

// global instance
extern KConfiguration KConfig;

// inline implementations

#define iimpl_getter(T, N, M) \
  inline T KConfiguration::get##N(NSString* key) { \
    return [defaults M##ForKey:key]; }
iimpl_getter(BOOL, Bool, bool)
iimpl_getter(int, Int, integer)
iimpl_getter(float, Float, float)
iimpl_getter(double, Double, double)
#undef iimpl_getter
#define iimpl_getter(T, N, M) \
  inline T KConfiguration::get##N(NSString* key, T def) { \
    T v = [defaults M##ForKey:key]; return v ? v : def; }
iimpl_getter(NSArray*, Array, array)
iimpl_getter(NSArray*, Strings, stringArray)
iimpl_getter(NSData*, Data, data)
iimpl_getter(NSDictionary*, Dict, dictionary)
iimpl_getter(NSString*, String, string)
iimpl_getter(NSURL*, URL, URL)
inline id KConfiguration::get(NSString* key, id def) {
  id v = [defaults objectForKey:key]; return v ? v : def;
}
#undef iimpl_getter

#define iimpl_setter(T, M) \
  inline void KConfiguration::set(NSString* key, T v) { \
    [defaults set##M:v forKey:key]; }
iimpl_setter(BOOL, Bool)
iimpl_setter(float, Float)
iimpl_setter(double, Double)
iimpl_setter(int, Integer)
iimpl_setter(NSURL*, URL)
iimpl_setter(id, Object)
inline void KConfiguration::set(NSString* key, NSColor* v) {
  //[defaults setColor:v forKey:key];
}
#undef iimpl_setter
