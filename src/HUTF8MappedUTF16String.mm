#import "HUTF8MappedUTF16String.h"

// ----------------------------------------------------------------------------
// Macros extracted from icu/unicode/utf16.h

/**
 * Is this code unit a lead surrogate (U+d800..U+dbff)?
 * @param c 16-bit code unit
 * @return TRUE or FALSE
 * @stable ICU 2.4
 */
#define U16_IS_LEAD(c) (((c)&0xfffffc00)==0xd800)

/**
 * Is this code unit a trail surrogate (U+dc00..U+dfff)?
 * @param c 16-bit code unit
 * @return TRUE or FALSE
 * @stable ICU 2.4
 */
#define U16_IS_TRAIL(c) (((c)&0xfffffc00)==0xdc00)

/**
 * Helper constant for U16_GET_SUPPLEMENTARY. (0x35fdc00)
 * @internal
 */
#define U16_SURROGATE_OFFSET ((0xd800<<10UL)+0xdc00-0x10000)

/**
 * Get a supplementary code point value (U+10000..U+10ffff)
 * from its lead and trail surrogates.
 * The result is undefined if the input values are not
 * lead and trail surrogates.
 *
 * @param lead lead surrogate (U+d800..U+dbff)
 * @param trail trail surrogate (U+dc00..U+dfff)
 * @return supplementary code point (U+10000..U+10ffff)
 * @stable ICU 2.4
 */
#define U16_GET_SUPPLEMENTARY(lead, trail) \
    (((uint32_t)(lead)<<10UL)+(uint32_t)(trail)-U16_SURROGATE_OFFSET)

/**
 * Get a code point from a string at a code point boundary offset,
 * and advance the offset to the next code point boundary.
 * (Post-incrementing forward iteration.)
 * "Unsafe" macro, assumes well-formed UTF-16.
 *
 * The offset may point to the lead surrogate unit
 * for a supplementary code point, in which case the macro will read
 * the following trail surrogate as well.
 * If the offset points to a trail surrogate, then that itself
 * will be returned as the code point.
 * The result is undefined if the offset points to a single, unpaired lead surrogate.
 *
 * @param s const UChar * string
 * @param i string offset
 * @param c output uint32_t variable
 * @see U16_NEXT
 * @stable ICU 2.4
 */
#define U16_NEXT_UNSAFE(s, i, c) { \
    (c)=(s)[(i)++]; \
    if(U16_IS_LEAD(c)) { \
        (c)=U16_GET_SUPPLEMENTARY((c), (s)[(i)++]); \
    } \
}

/**
 * Get a code point from a string at a code point boundary offset,
 * and advance the offset to the next code point boundary.
 * (Post-incrementing forward iteration.)
 * "Safe" macro, handles unpaired surrogates and checks for string boundaries.
 *
 * The offset may point to the lead surrogate unit
 * for a supplementary code point, in which case the macro will read
 * the following trail surrogate as well.
 * If the offset points to a trail surrogate or
 * to a single, unpaired lead surrogate, then that itself
 * will be returned as the code point.
 *
 * @param s const UChar * string
 * @param i string offset, must be i<length
 * @param length string length
 * @param c output UChar32 variable
 * @see U16_NEXT_UNSAFE
 * @stable ICU 2.4
 */
#define U16_NEXT(s, i, length, c) { \
    (c)=(s)[(i)++]; \
    if(U16_IS_LEAD(c)) { \
        uint16_t __c2; \
        if((i)<(length) && U16_IS_TRAIL(__c2=(s)[(i)])) { \
            ++(i); \
            (c)=U16_GET_SUPPLEMENTARY((c), __c2); \
        } \
    } \
}

// end of icu/unicode/utf16.h
// ----------------------------------------------------------------------------


HUTF8MappedUTF16String::~HUTF8MappedUTF16String() {
  if (u8to16_table_ && !u8to16_table_weak_) {
    delete u8to16_table_; u8to16_table_ = NULL;
  }
  if (u16_buf_ && !u16_weak_) { delete u16_buf_; u16_buf_ = NULL; }
  if (u8_buf_) { delete u8_buf_; u8_buf_ = NULL; }
}


void HUTF8MappedUTF16String::setUTF16String(unichar *u16buf, size_t u16len,
                                            bool weak/*=true*/) {
  // delete old
  if (u16_buf_ && !u16_weak_) delete u16_buf_;
  // set new
  u16_len_ = u16len;
  u16_buf_ = u16buf;
  u16_weak_ = weak;
  // since we no longer can guarantee integrity of the map, let's waste it
  if (u8to16_table_ && !u8to16_table_weak_)
    delete u8to16_table_;
  u8to16_table_ = NULL;
  u8_len_ = 0;
  if (u8_buf_) delete u8_buf_;
}


void HUTF8MappedUTF16String::setNSString(NSString *str, NSRange range) {
  setUTF16String(NULL, range.length, false);
  u16_buf_ = new unichar[u16_len_];
  [str getCharacters:u16_buf_ range:range];
}


const uint8_t *HUTF8MappedUTF16String::convert() {
  if (u8_buf_) delete u8_buf_;
  u8_buf_ = new uint8_t[maximumUTF8Size()+1];
  size_t u8len = convert(u8_buf_);
  u8_buf_[u8len] = '\0';
  return u8_buf_;
}


void HUTF8MappedUTF16String::convert(std::string &str) {
  str.resize(maximumUTF8Size());
  char *pch = (char*)str.data();
  convert((uint8_t*)pch);
  str.resize(u8_len_);
}


size_t HUTF8MappedUTF16String::convert(uint8_t *u8buf,
                                       size_t *u8to16_table/*=NULL*/) {
  // setup u8to16_table
  if (u8to16_table_ && !u8to16_table_weak_)
    delete u8to16_table_;
  if (u8to16_table) {
    u8to16_table_ = u8to16_table;
    u8to16_table_weak_ = true;
  } else {
    u8to16_table_ = new size_t[maximumUTF8Size()];
    u8to16_table_weak_ = false;
  }
  
  // reset u8_len_
  u8_len_ = 0;
  
  // For each UTF-16 character...
  for (size_t u16i=0; u16i < u16_len_; ) {
    // Retrieve 1-2 UTF-16 characters, forming one 32-bit unicode character
    uint32_t u32c = 0;
    size_t u16i_next = u16i;
    // slower, but "safer"
    // U16_NEXT(u16_buf_, u16i_next, u16_len_, u32c);
    // faster, but does not handle unpaired surrogates or checks bounds
    U16_NEXT_UNSAFE(u16_buf_, u16i_next, u32c); 
    
    // u16 offset added to |u8to16_table_|
    size_t u16ix = u16i;
    
    // Append u32c to u8buf (1-4 bytes)
    if ((uint32_t)u32c <= 0x7f) {
      u8to16_table_[u8_len_] = u16ix;
      u8buf[u8_len_++] = (uint8_t)u32c;
    } else {
      if ((uint32_t)u32c <= 0x7ff) {
        u8to16_table_[u8_len_] = u16ix;
        u8buf[u8_len_++] = (uint8_t)((u32c>>6)|0xc0);
      } else {
        if ((uint32_t)u32c <= 0xffff) {
          u8to16_table_[u8_len_] = u16ix;
          u8buf[u8_len_++] = (uint8_t)((u32c>>12)|0xe0);
        } else {
          u8to16_table_[u8_len_] = u16ix;
          u8buf[u8_len_++] = (uint8_t)((u32c>>18)|0xf0);
          u8to16_table_[u8_len_] = u16ix;
          u8buf[u8_len_++] = (uint8_t)(((u32c>>12)&0x3f)|0x80);
        }
        u8to16_table_[u8_len_] = u16ix;
        u8buf[u8_len_++] = (uint8_t)(((u32c>>6)&0x3f)|0x80);
      }
      u8to16_table_[u8_len_] = u16ix;
      u8buf[u8_len_++] = (uint8_t)((u32c&0x3f)|0x80);
    }
    
    u16i = u16i_next;
  }
  
  return u8_len_;
}


NSRange HUTF8MappedUTF16String::UTF16RangeForUTF8Range(NSRange u8range) {
  if (u8range.location+u8range.length > u8_len_) {
    [NSException raise:NSRangeException
                format:@"Range %@ beyond end (%zu) of data",
                       NSStringFromRange(u8range), u8_len_];
    return NSRange();
  }
  NSRange u16range = {u8to16_table_[u8range.location], 0};
  // Because we never record 2nd part of a pair when building our table, this
  // should never happen. We keep the code (out-commented) for clarity sake:
  //if (U16_IS_TRAIL(u16_buf_[u16range.location]))
  //  --(u16range.location);
  if (u8range.length != 0) {
    size_t endLocation = u8to16_table_[u8range.location+u8range.length-1];
    if (U16_IS_LEAD(u16_buf_[endLocation])) {
      ++endLocation; // expects well-formed UTF-16
      assert(endLocation < u16_len_);
    }
    u16range.length = (endLocation+1) - u16range.location;
  }
  return u16range;
}
