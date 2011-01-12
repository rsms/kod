// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "kod_node_interface.h"

class KNodeParseEntry : public KNodeIOEntry {
 public:
  KNodeParseEntry(NSUInteger modificationIndex,
                  NSInteger changeDelta,
                  kod::ExternalUTF16String *source,
                  dispatch_block_t block)
      : modificationIndex_(modificationIndex)
      , changeDelta_(changeDelta) {
    block_ = [block copy];
    source_ = source;
  }

  virtual ~KNodeParseEntry() {
    [block_ release];
  }

  void perform() {
    block_();
    KNodeIOEntry::perform();
  }

  bool mergeWith(KNodeParseEntry *olderEntry);

  NSUInteger modificationIndex() const { return modificationIndex_; };
  NSUInteger &modificationIndex() { return modificationIndex_; };

  NSInteger changeDelta() const { return changeDelta_; };
  NSInteger &changeDelta() { return changeDelta_; };

  kod::ExternalUTF16String *source() const { return source_; };

 protected:
  dispatch_block_t block_;
  NSUInteger modificationIndex_;
  NSInteger changeDelta_;
  kod::ExternalUTF16String *source_;
};
