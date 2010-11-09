//
//  NSStringICUAdditions.h
//  CocoaICU
//
//  Created by Aaron Evans on 11/19/06.
//  Copyright 2006 Aaron Evans. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class ICUPattern;

@interface NSString (NSStringICUAdditions)

/*!
    @method     nativeUTF16Encoding
    @abstract   The native UTF16 encoding on the given machine.
    @discussion The native UTF16 encoding on the given machine.
*/
+(NSStringEncoding)nativeUTF16Encoding;

/*!
    @method     stringWithICUString:
    @abstract   Create an NSString from a UTF16 encoded string.
    @discussion Create an NSString from a UTF16 encoded string.
*/
+(NSString *)stringWithICUString:(void *)utf16EncodedString;

/*!
    @method     UTF16String
    @abstract   Returns a UTF16 encoded string in the native encoding.
    @discussion This string has a retain policy equivalent to UTF8String. In
 other words, if you want to keep this string around beyond the given autorelease
 context, you need to copy the returned string.
*/
-(void *)UTF16String;


/*!
 @method     copyUTF16String
 @abstract   returns a copy
 @discussion Returns a UTF16 encoded string in the native encoding. The returned
 buffer must eventually be freed.
*/
-(void *)copyUTF16String;

/*!
    @method     findPattern:
    @abstract   Finds the given expression and and groups.
	@discussion Returns the match and any grouped matches in the returned 
	array.  The first element of the array is the entire match and subsequent
	elements are the groups in the order the matches occur.
*/
-(NSArray *)findPattern:(NSString *)aRegex;

/*!
    @method     componentsSeparatedByPattern:
    @abstract   Returns the components separated by the given pattern.
    @discussion Break a string into components where components separated
	by occurrences of the given pattern.
*/
-(NSArray *)componentsSeparatedByPattern:(NSString *)aRegex;

/*!
    @method     replaceOccurrencesOfPattern:withString:
    @abstract   Replace occurrences of the pattern with the replacement text.
    @discussion Replace occurrences of the pattern with the replacement text.
   The replacement text may contain backrerferences.
*/
-(NSString *)replaceOccurrencesOfPattern:(NSString *)aPattern withString:(NSString *)replacementText;

/*!
    @method     matchesPattern:
    @abstract   Returns YES if the string matches the entire pattern.
    @discussion Returns YES if the string matches the entire pattern.
*/
-(BOOL)matchesPattern:(NSString *)aRegex;

@end
