// Copyright (c) 2009 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#ifndef BASE_SCOPED_NSOBJECT_H_
#define BASE_SCOPED_NSOBJECT_H_
#pragma once

#import <Foundation/Foundation.h>
//#import "basictypes.h"

//[RA]#import "compiler_specific.h"
#define WARN_UNUSED_RESULT // nothing

// scoped_nsobject<> is patterned after scoped_ptr<>, but maintains ownership
// of an NSObject subclass object.  Style deviations here are solely for
// compatibility with scoped_ptr<>'s interface, with which everyone is already
// familiar.
//
// When scoped_nsobject<> takes ownership of an object (in the constructor or
// in reset()), it takes over the caller's existing ownership claim.  The
// caller must own the object it gives to scoped_nsobject<>, and relinquishes
// an ownership claim to that object.  scoped_nsobject<> does not call
// -retain.
//
// scoped_nsobject<> is not to be used for NSAutoreleasePools. For
// NSAutoreleasePools use ScopedNSAutoreleasePool from
// scoped_nsautorelease_pool.h instead.
// We check for bad uses of scoped_nsobject and NSAutoreleasePool at compile
// time with a template specialization (see below).
template<typename NST>
class scoped_nsobject {
 public:
  typedef NST* element_type;

  explicit scoped_nsobject(NST* object = nil)
      : object_(object) {
  }

  ~scoped_nsobject() {
    [object_ release];
  }

  void reset(NST* object = nil) {
    // We intentionally do not check that object != object_ as the caller must
    // already have an ownership claim over whatever it gives to scoped_nsobject
    // and scoped_cftyperef, whether it's in the constructor or in a call to
    // reset().  In either case, it relinquishes that claim and the scoper
    // assumes it.
    [object_ release];
    object_ = object;
  }

  bool operator==(NST* that) const {
    return object_ == that;
  }

  bool operator!=(NST* that) const {
    return object_ != that;
  }

  operator NST*() const {
    return object_;
  }

  NST* get() const {
    return object_;
  }

  void swap(scoped_nsobject& that) {
    NST* temp = that.object_;
    that.object_ = object_;
    object_ = temp;
  }

  // scoped_nsobject<>::release() is like scoped_ptr<>::release.  It is NOT
  // a wrapper for [object_ release].  To force a scoped_nsobject<> object to
  // call [object_ release], use scoped_nsobject<>::reset().
  NST* release() WARN_UNUSED_RESULT {
    NST* temp = object_;
    object_ = nil;
    return temp;
  }

 private:
  NST* object_;

  DISALLOW_COPY_AND_ASSIGN(scoped_nsobject);
};

// Specialization to make scoped_nsobject<id> work.
template<>
class scoped_nsobject<id> {
 public:
  typedef id element_type;

  explicit scoped_nsobject(id object = nil)
      : object_(object) {
  }

  ~scoped_nsobject() {
    [object_ release];
  }

  void reset(id object = nil) {
    // We intentionally do not check that object != object_ as the caller must
    // already have an ownership claim over whatever it gives to scoped_nsobject
    // and scoped_cftyperef, whether it's in the constructor or in a call to
    // reset().  In either case, it relinquishes that claim and the scoper
    // assumes it.
    [object_ release];
    object_ = object;
  }

  bool operator==(id that) const {
    return object_ == that;
  }

  bool operator!=(id that) const {
    return object_ != that;
  }

  operator id() const {
    return object_;
  }

  id get() const {
    return object_;
  }

  void swap(scoped_nsobject& that) {
    id temp = that.object_;
    that.object_ = object_;
    object_ = temp;
  }

  // scoped_nsobject<>::release() is like scoped_ptr<>::release.  It is NOT
  // a wrapper for [object_ release].  To force a scoped_nsobject<> object to
  // call [object_ release], use scoped_nsobject<>::reset().
  id release() WARN_UNUSED_RESULT {
    id temp = object_;
    object_ = nil;
    return temp;
  }

 private:
  id object_;

  DISALLOW_COPY_AND_ASSIGN(scoped_nsobject);
};

// Do not use scoped_nsobject for NSAutoreleasePools, use
// ScopedNSAutoreleasePool instead. This is a compile time check. See details
// at top of header.
template<>
class scoped_nsobject<NSAutoreleasePool> {
 private:
  explicit scoped_nsobject(NSAutoreleasePool* object = nil);
  DISALLOW_COPY_AND_ASSIGN(scoped_nsobject);
};

#endif  // BASE_SCOPED_NSOBJECT_H_
