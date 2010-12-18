#define SI static inline
#ifdef __cplusplus
extern "C" {
#endif

// Kod configuration
// All operations are thread safe unless stated otherwise

SI NSUserDefaults* kconf_defaults() { return [NSUserDefaults standardUserDefaults]; }
SI NSBundle*       kconf_bundle() { return [NSBundle mainBundle]; }

// URL for a resource
// To get the path for a resource, simply:  [kconf_res_url(relpath) path]
NSURL* kconf_res_url(NSString* relpath);

// URL for something in the bundle's shared support directory
NSURL* kconf_support_url(NSString* relpath);


// Getters

#define _OIMPL(M) { id v = [kconf_defaults() M##ForKey:key]; return v ? v : def; }
#define _NIMPL(M) { NSNumber *n = kconf_object(key); \
  if (!n || ![n isKindOfClass:[NSNumber class]]) return def; \
  return [n M]; }

SI id            kconf_object(NSString *key) { return [kconf_defaults() objectForKey:key]; }

SI NSArray*      kconf_array(NSString* key, NSArray* def)     _OIMPL(array)
SI NSArray*      kconf_strings(NSString* key, NSArray* def)   _OIMPL(stringArray)
SI NSData*       kconf_data(NSString* key, NSData* def)       _OIMPL(data)
SI NSDictionary* kconf_dict(NSString* key, NSDictionary* def) _OIMPL(dictionary)
SI NSString*     kconf_string(NSString* key, NSString* def)   _OIMPL(string)
SI NSURL*        kconf_url(NSString* key, NSURL* def)         _OIMPL(URL)
   NSColor*      kconf_color(NSString* key, NSColor* def);

SI BOOL          kconf_bool(NSString* key, BOOL def)          _NIMPL(boolValue)
SI int           kconf_int(NSString* key, int def)            _NIMPL(intValue)
SI float         kconf_float(NSString* key, float def)        _NIMPL(floatValue)
SI double        kconf_double(NSString* key, double def)      _NIMPL(doubleValue)


// Setters

#undef  _OIMPL
#define _OIMPL(M) { if (v) [kconf_defaults() set##M:v forKey:key]; \
                    else [kconf_defaults() removeObjectForKey:key]; }
#undef  _NIMPL
#define _NIMPL(M) { [kconf_defaults() set##M:v forKey:key]; }

SI void kconf_set_object(NSString* key, id v)       _OIMPL(Object)

SI void kconf_set_url(NSString* key, NSURL* v)      _OIMPL(URL)
   void kconf_set_color(NSString* key, NSColor* v);

SI void kconf_set_bool(NSString* key, BOOL v)       _NIMPL(Bool)
SI void kconf_set_int(NSString* key, int v)         _NIMPL(Integer)
SI void kconf_set_float(NSString* key, float v)     _NIMPL(Float)
SI void kconf_set_double(NSString* key, double v)   _NIMPL(Double)


// Remover

SI void kconf_remove(NSString* key) { [kconf_defaults() removeObjectForKey:key]; }


#undef SI
#ifdef __cplusplus
}  // extern "C"
#endif