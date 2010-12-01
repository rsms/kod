@interface NSString (EditDistance)

/**
 * Returns 1.0 if the strings are entirly different, 0.0 if the strings are
 * identical, and a number in between if they are similar. Lower means shorter
 * edit distance.
 */
- (double)editDistanceToString:(NSString*)otherString;

@end
