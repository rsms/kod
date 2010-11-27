#ifndef H_UTF8_MAPPED_UTF16_STRING_H_
#define H_UTF8_MAPPED_UTF16_STRING_H_

#import <Foundation/Foundation.h>
#import <string>

/*
 * Convert a UTF-16 string to UTF-8, mapping indices to provide low-complexity
 * range and index lookups.
 *
 * Copyright 2010 Rasmus Andersson. All rights reserved.
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */
class HUTF8MappedUTF16String {
 protected:
  unichar  *u16_buf_;
  size_t    u16_len_;
  bool      u16_weak_; // someone else owns |u16_buf_|?
  
  size_t   *u8to16_table_; // owned unless NULL
  bool      u8to16_table_weak_; // someone else owns |u8to16_table_|?
  
  uint8_t  *u8_buf_; // owned unless NULL
  size_t    u8_len_; // valid after a call to |convert|
  
 public:
  HUTF8MappedUTF16String(unichar *u16buf=NULL, size_t u16len=0)
      : u16_buf_(u16buf)
      , u16_len_(u16len)
      , u16_weak_(true)
      , u8to16_table_(NULL)
      , u8to16_table_weak_(true)
      , u8_buf_(NULL)
      , u8_len_(0) {
  }
  ~HUTF8MappedUTF16String();
  
  // (Re)set to represent UTF-16 string data
  void setUTF16String(unichar *u16buf, size_t u16len, bool weak=true);
  
  /**
   * (Re)set to represent an NSString. Will make an implicit managed copy of its
   * UTF-16 characters, thus owning a strong reference meaning you can let |str|
   * die without messing up the life of |this|.
   */
  void setNSString(NSString *str, NSRange range);
  
  // The number of UTF-16 characters this object represents
  inline size_t length() const { return u16_len_; }
  
  // The UTF-16 characters this object represents
  inline const unichar *characters() const { return u16_buf_; }
  
  // Access the UTF-16 character at index. Unchecked.
  inline unichar const &operator[](size_t u16index) const {
    // You can use this alternate prototype to allow modification:
    //inline unichar &operator[] (size_t u16index) {
    assert(u16index < u16_len_);
    return u16_buf_[u16index];
  }
  
  // Maximum number of bytes needed to store a UTF-8 representation.
  inline size_t maximumUTF8Size() { return u16_len_*4; }
  
  /**
   * Convert the represented Unicode string to UTF-8, returning a (internally
   * allocated) null-terminated UTF-8 C string, which will be valid as long as
   * |this| is alive or until |convert| is called. You can find out the length
   * of the returned string from |UTF8Length|.
   *
   * See |convert(uint8_t*, size_t*)| for details.
   */
  const uint8_t *convert();
  
  // Fill |str| with the UTF-8 representation
  void convert(std::string &str);
  
  /**
   * Convert the represented Unicode string to UTF-8, filling |u8buf|.
   *
   * @param u8buf         A byte buffer to be filled which must be at least
   *                      |maximumUTF8Size| bytes long.
   *
   * @param u8to16_table  A user-allocated lookup table which must have at least
   *                      |maximumUTF8Size| slots. If |u8to16_table| is NULL the
   *                      table will be created and managed internally.
   *
   * @returns Number of bytes written to |u8buf|
   */
  size_t convert(uint8_t *u8buf, size_t *u8to16_table=NULL);
  
  // The number of bytes used for the UTF-8 representation
  inline size_t UTF8Length() const { return u8_len_; }
  
  /**
   * Return index of UTF-16 character represented by UTF-8 character at
   * |u8index|. Unchecked and expects an index less than |UTF8Length|.
   */
  inline size_t UTF16IndexForUTF8Index(size_t u8index) const {
    assert(u8index < u8_len_);
    return u8to16_table_[u8index];
  }
  
  /**
   * Convert a UTF-8 range into the range of it's equivalent UTF-16 characters
   * in |characters|. This has low complexity because a lookup table is
   * utilized. Automatically expands to cover any pairs.
   *
   * @param u8range Range in UTF-8 space
   * @returns       valid range in UTF-16 space
   */
  NSRange UTF16RangeForUTF8Range(NSRange u8range);
  
  // Faster version of UTF16RangeForUTF8Range without checks
  inline NSRange unsafeUTF16RangeForUTF8Range(NSRange u8range) {
    NSRange u16range = {u8to16_table_[u8range.location], 0};
    if (u8range.length != 0) {
      size_t endLocation = u8to16_table_[u8range.location+u8range.length-1];
      if ((u16_buf_[endLocation]&0xfffffc00)==0xd800) // U16_IS_LEAD
        ++endLocation; // expects well-formed UTF-16
      u16range.length = (endLocation+1) - u16range.location;
    }
    return u16range;
  }
};

#endif  // H_UTF8_MAPPED_UTF16_STRING_H_
