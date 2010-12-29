#import <node.h>

extern NSString * const KNodeErrorDomain;

@interface NSObject (v8)
/**
 * Convert a Cocoa object to a V8 value.
 *
 * Conversions:
 *   NSNull --> Null
 *   NSNumber (BOOL) --> Boolean
 *   NSNumber (int) --> Integer
 *   NSNumber --> Number
 *   NSValue --> External
 *   NSString --> String
 *   NSDate --> Date
 *   // NodeJSFunction --> Function
 *   NSArray --> Array
 *   NSSet --> Array
 *   NSData --> node::Buffer
 *   NSDictionary --> Object
 *   NSObject (description) --> String
 */
- (v8::Local<v8::Value>)v8Value;

/**
 * Convert a V8 value to a Cocoa object.
 *
 * Returns nil if value.IsEmpty() or conversion failed (i.e. unsupported type).
 *
 * Conversions:
 *   Undefined --> NSNull
 *   Null --> NSNull
 *   Boolean --> NSNumber (numberWithBool:)
 *   Number/Int32 --> NSNumber (numberWithInt:)
 *   Number/UInt32 --> NSNumber (numberWithUnsignedInt:)
 *   Number --> NSNumber (numberWithDouble:)
 *   External --> NSValue (valueWithPointer:)
 *   String --> NSString
 *   Date --> NSDate
 *   RegExp --> NSString
 *   // Function --> NodeJSFunction
 *   Array --> NSArray
 *   node::Buffer --> NSData
 *   Object --> Dictionary
 */
+ (id)fromV8Value:(v8::Local<v8::Value>)value;
@end

@interface NSString (v8)
+ (NSString*)stringWithV8String:(v8::Local<v8::String>)str;
@end

@interface NSError (v8)
+ (NSError*)nodeErrorWithTryCatch:(v8::TryCatch&)tryCatch;
+ (NSError*)nodeErrorWithFormat:(NSString *)format, ...;
@end
