#ifndef KOD_EXTERNAL_UTF16_STRING_H_
#define KOD_EXTERNAL_UTF16_STRING_H_
#ifdef __cplusplus

#import <node.h>

namespace kod {

/*!
 * Wraps a buffer of UTF-16 characters and can be passed to a v8::String which
 * will then manage the life-cycle of the data (GC-ing as needed).
 */
class ExternalUTF16String : public v8::String::ExternalStringResource {
 public:
  /*!
   * Create an instance which refers to |data| of |length|
   */
  ExternalUTF16String(unichar *data, size_t length)
      : data_(data)
      , length_(length) {
  }
  
#ifdef __OBJC__
  /*!
   * Creates an instance with a copy of |src|
   */
  ExternalUTF16String(NSString *src) {
    length_ = [src length];
    data_ = new uint16_t[length_];
    [src getCharacters:data_ range:NSMakeRange(0, length_)];
  }
#endif  // __OBJC__

  virtual ~ExternalUTF16String() {
    delete data_;
  }

  // The string data from the underlying buffer
  virtual const uint16_t* data() const { return data_; }

  // Number of characters.
  virtual size_t length() const { return length_; }

 protected:
  uint16_t *data_;
  size_t length_;
};


};  // namespace kod

#endif  // __cplusplus
#endif  // KOD_EXTERNAL_UTF16_STRING_H_
