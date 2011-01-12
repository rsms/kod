// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "k_objc_prop.h"

KObjCPropFlags k_objc_propattrs(objc_property_t prop,
                                char *returnType,
                                NSString **getterName,
                                NSString **setterName) {
  KObjCPropFlags flags = 0;
  if (getterName) *getterName = NULL;
  if (setterName) *setterName = NULL;
  if (returnType) *returnType = 0;
  const char *propattrs = property_getAttributes(prop);
  if (!propattrs || propattrs[0] != 'T')
    return 0;
  //NSLog(@"propattrs -> %s", propattrs);
  int propattrslen = strlen(propattrs);
  char section = 0;
  for (int i=0; i<propattrslen; ++i) {
    char c = propattrs[i];
    if (c == ',') {
      section = 0;
    } else if (section == 0) {
      section = c;
      switch (section) {
        case 'R': flags &= ~KObjCPropWritable; break;
        case '&': flags |= KObjCPropRetain; break;
        case 'C': flags |= KObjCPropCopy; break;
        case 'N': flags |= KObjCPropNonAtomic; break;
        case 'D': flags |= KObjCPropDynamic; break;
        case 'W': flags |= KObjCPropWeak; break;
        case 'P': flags |= KObjCPropGC; break;
      }
    } else if (section == 'T') {
      switch (c) {
        case '^':
          flags |= KObjCPropReturnsPointer; break;
        case '(': // union
        case '{': // struct
          // unsupported
          return KObjCPropUnsupported;
        default:
          if (returnType)
            *returnType = c;
          break;
      }
      flags |= KObjCPropReadable;
      flags |= KObjCPropWritable;
    } else if (section == 'G') {
      // getter
      if (getterName) {
        const char *start = propattrs+i+1;
        const char *end = start;
        while ( (*end != ',') && end && ++end );
        *getterName = [[NSString alloc] initWithBytes:start
                                               length:end-start
                                             encoding:NSUTF8StringEncoding];
        [*getterName autorelease];
      }
    } else if (section == 'S') {
      // setter
      if (setterName) {
        const char *start = propattrs+i+1;
        const char *end = start;
        while ( (*end != ',') && (*end != ':') && end && ++end );
        *setterName = [[NSString alloc] initWithBytes:start
                                               length:end-start
                                             encoding:NSUTF8StringEncoding];
        [*setterName autorelease];
      }
    } else {
      break;
    }
  }
  if (getterName && !*getterName) {
    *getterName = [NSString stringWithUTF8String:property_getName(prop)];
  }
  if (setterName && !*setterName) {
    // construct setter name from |name|
    const char *name = property_getName(prop);
    *setterName = [NSString stringWithFormat:@"set%c%s:",
                   (char)toupper(name[0]), name+1];
  }

  return flags;
}
