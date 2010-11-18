#ifndef H_OBJC_PTR_H_
#define H_OBJC_PTR_H_

/**
 * C++ wrapper for an Objective-C object, receiving retain from constructor and
 * release from destructor, making it possible to use Objective-C objects with
 * STL and friends.
 */
class HObjCPtr {
 protected:
  id object_;
 public:
  HObjCPtr(id object) { object_ = [object retain]; }
  HObjCPtr(HObjCPtr const &other) { object_ = [other.object_ retain]; }
  ~HObjCPtr() {
    [object_ release];
    object_ = nil;
  }
  HObjCPtr & operator=(HObjCPtr const & other) {
    id old = object_; object_ = [other.object_ retain]; [old release];
    return *this;
  }
  inline id get() { return object_; }
};

#endif  // H_OBJC_PTR_H_
