//
//  ICUMatcher.m
//  CocoaICU
//
//  Created by Aaron Evans on 11/29/06.
//  Copyright 2006 Aaron Evans. All rights reserved.
//

#import "ICUMatcher.h"
#import "NSStringICUAdditions.h"
#import "ICUPattern.h"

size_t InitialGroupSize = 128;

struct URegularExpression;
/**
* Structure represeting a compiled regular rexpression, plus the results
 *    of a match operation.
 * @draft ICU 3.0
 */
typedef struct URegularExpression URegularExpression;

#define U_HIDE_DRAFT_API 1
#define U_DISABLE_RENAMING 1

#import <unicode/uregex.h>
#import <unicode/ustring.h>

#define CheckStatus(status) 	if(U_FAILURE(status)) { [NSException raise:@"Find Exception" format:@"%s", u_errorName(status)]; }


@interface ICUMatcher (Private)
-(NSString *)performReplacementWithString:(NSString *)aReplacementString replaceAll:(BOOL)replacingAll;
@end

@implementation ICUMatcher

+(ICUMatcher *)matcherWithPattern:(ICUPattern *)p overString:(NSString *)stringToSearchOver {
	return [[[ICUMatcher class] alloc] initWithPattern:p overString:stringToSearchOver];
}

-(ICUMatcher *)initWithPattern:(ICUPattern *)p overString:(NSString *)aStringToSearch; {
	if(![super init])
		return nil;

	[self setPattern:p];
	[[self pattern] setStringToSearch:aStringToSearch];

	return self;
}



-(void)setPattern:(ICUPattern *)p {
	pattern = p;
}

-(BOOL)matches {
	URegularExpression *re = [[self pattern] re];
	
	UErrorCode status = 0;
	BOOL matches = uregex_matches(re, 0, &status);
	CheckStatus(status);

	return matches;
}


/*
 Find the first matching substring of the input string that matches the pattern.
 
 The search for a match begins at the specified index. If a match is found, uregex_start(), uregex_end(), and uregex_group() will provide more information regarding the match.
 */
-(BOOL)findNext {
	URegularExpression *re = [[self pattern] re];
	UErrorCode status = 0;
	UBool r = uregex_findNext(re, &status);
	CheckStatus(status);

	return r;
}

-(BOOL)findFromIndex:(unsigned)index {
	URegularExpression *re = [[self pattern] re];
	[self reset];

	UErrorCode status = 0;
	UBool r = uregex_find(re, index, &status);
	CheckStatus(status);

	return r;
}

-(NSString *)group {
	NSString *stringToMatch = [[self pattern] stringToSearch];
	return [stringToMatch substringWithRange:[self rangeOfMatch]];
}

-(NSString *)groupAtIndex:(unsigned)groupIndex {
	size_t groupSize = InitialGroupSize;
	URegularExpression *re = [[self pattern] re];

	while(YES) { 
		UErrorCode status = 0;
		UChar *dest = (UChar *)NSZoneCalloc([self zone], groupSize, sizeof(UChar));
		int32_t buffSize = uregex_group(re, groupIndex, dest, groupSize, &status);

		if(U_BUFFER_OVERFLOW_ERROR == status) {
			groupSize *= 2;
			NSZoneFree([self zone], dest);
			continue;
		}

		CheckStatus(status);

		groupSize = InitialGroupSize; // reset to default
		NSString *result = [[NSString alloc] initWithBytes:dest length:buffSize*sizeof(UChar) encoding:[NSString nativeUTF16Encoding]];
		NSZoneFree([self zone], dest);
		return result;
	}
}

-(unsigned)numberOfGroups {
	URegularExpression *re = [[self pattern] re];
	UErrorCode status = 0;
	int numberOfGroups = uregex_groupCount(re, &status);
	CheckStatus(status);
	
	return numberOfGroups;
}

-(BOOL)lookingAt:(unsigned)index {
	UErrorCode status = 0;
	URegularExpression *re = [[self pattern] re];
	BOOL matches = uregex_lookingAt(re, 0, &status);
	CheckStatus(status);
	return matches;
}

-(ICUPattern *)pattern {
	return pattern;
}

-(NSString *)performReplacementWithString:(NSString *)aReplacementString replaceAll:(BOOL)replacingAll {

	UErrorCode status = 0;
	UChar *replacementText = [aReplacementString UTF16String];
	URegularExpression *re = [[self pattern] re];
	unsigned int searchTextLength = [[[self pattern] stringToSearch] length];
	
	BOOL replacementCompleted = NO;
	int resultLength = 0;
	size_t destStringBufferSize = searchTextLength * 2;
	UChar *destString = NULL;
	while(!replacementCompleted) {
		
		if(!destString) // attempts to increase buffer happen on failure below
			destString = NSZoneCalloc([self zone], destStringBufferSize, sizeof(UChar));
		
		if(!destString)
			[NSException raise:@"Find Exception"
						format:@"Could not allocate memory for replacement string"];
	
		status = 0;
		if(replacingAll)
			resultLength = uregex_replaceAll(re, replacementText, -1, destString, destStringBufferSize, &status);
		else
			resultLength = uregex_replaceFirst(re, replacementText, -1, destString, destStringBufferSize, &status);

		// realloc some more space if possible
		if(status == U_BUFFER_OVERFLOW_ERROR) {

			destStringBufferSize = resultLength + 1;
			
			UChar *prevString = destString;
			destString = NSZoneRealloc([self zone], destString, destStringBufferSize*sizeof(UChar));
			
			if(destString == NULL) {
				NSZoneFree([self zone], prevString);
				[NSException raise:@"Find Exception"
							format:@"Could not allocate memory for replacement string"];
			}
		} else if(U_FAILURE(status)) {
			NSZoneFree([self zone], destString);
			[NSException raise:@"Find Exception"
						format:@"Could not perform find and replace: %s", u_errorName(status)];
		} else {
			replacementCompleted = YES;
		}
	}
	
	NSString *result = [[NSString alloc] initWithBytes:destString
												 length:resultLength * sizeof(UChar)
											   encoding:[NSString nativeUTF16Encoding]];
	NSZoneFree([self zone], destString);
	return result;	
}


-(NSString *)replaceAllWithString:(NSString *)aReplacementString {
	return [self performReplacementWithString:aReplacementString replaceAll:YES];
}

-(NSString *)replaceFirstWithString:(NSString *)aReplacementString {
	return [self performReplacementWithString:aReplacementString replaceAll:NO];
}

-(void)reset {
	[[self pattern] reset];
}

-(NSRange)rangeOfMatch {
	return [self rangeOfMatchGroup:0];
}

-(NSRange)rangeOfMatchGroup:(unsigned)groupNumber {
	UErrorCode status = 0;
	URegularExpression *re = [[self pattern] re];
	int start = uregex_start(re, groupNumber, &status);
	CheckStatus(status);
	
	int end = uregex_end(re, groupNumber, &status);
	CheckStatus(status);
	
	return NSMakeRange(start == -1 ? NSNotFound : start, end-start);
}

@end
