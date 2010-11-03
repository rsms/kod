@interface NSColor (web)

/**
 * Return an NSColor or nil by parsing |name|.
 *
 * Supported formats:
 *
 *  - #RGB
 *  - #RRGGBB
 *  - #RRGGBBAA
 *  - rgb(R[0-255], G[0-255], B[0-255])
 *  - rgba(R[0-255], G[0-255], B[0-255], A[0-1])
 *  - <symbolic>
 *
 * Where <symbolic> can be any standard name (e.g. "red", "aquamarine" or
 * "dark salmon").
 *
 * If |name| is unparsable, nil is returned.
 */
+ (NSColor*)colorWithCssDefinition:(NSString*)name;

@end
