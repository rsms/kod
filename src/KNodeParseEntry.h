// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "kod_node_interface.h"

@class KDocument;

class KNodeParseEntry : public KNodeIOEntry {
 public:
  KNodeParseEntry(NSUInteger modificationIndex,
                  NSInteger changeDelta,
                  KDocument *document);

  virtual ~KNodeParseEntry();

  void perform();
  bool mergeWith(KNodeParseEntry *olderEntry);

  NSUInteger modificationIndex() const { return modificationIndex_; };
  NSUInteger &modificationIndex() { return modificationIndex_; };

  NSInteger changeDelta() const { return changeDelta_; };
  NSInteger &changeDelta() { return changeDelta_; };

  kod::ExternalUTF16String *source() const { return source_; };
  kod::ExternalUTF16String *source(bool create);

  KDocument *document() const { return document_; };

 protected:
  KDocument *document_;
  NSUInteger modificationIndex_;
  NSInteger changeDelta_;
  kod::ExternalUTF16String *source_;
};
