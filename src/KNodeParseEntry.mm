// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "KNodeParseEntry.h"
#import "KDocument.h"
#import "knode_ns_additions.h"
#import "ASTNode.hh"
#import "ASTNodeWrapper.h"
#import "common.h"
#import "ExternalUTF16String.h"

// set to 1 to enable resource usage sampling and logging
#define KOD_WITH_K_RUSAGE 1
#import "KRUsage.hh"


KNodeParseEntry::KNodeParseEntry(NSUInteger modificationIndex,
                                 NSInteger changeDelta,
                                 KDocument *document)
    : modificationIndex_(modificationIndex)
    , changeDelta_(changeDelta)
    , source_(NULL) {
  // Export a copy of the document's current text state into V8 which will be
  // governed by the V8 GC
  //source_ = new kod::ExternalUTF16String(document.textStorage.string);

  // keep a ref to the document
  document_ = [document retain];
}


KNodeParseEntry::~KNodeParseEntry() {
  [document_ release];
  // this free up underlying memory, but not the container itself, which
  // eventually will be garbage collected by V8.
  if (source_)
    source_->clear();
}


kod::ExternalUTF16String *KNodeParseEntry::source(bool create) {
  if (create && !source_) {
    NSString *text = [[document_ textView] textStorage].string;
    kod::ExternalUTF16String *source = new kod::ExternalUTF16String(text);
    if (!h_casptr(&source_, NULL, source)) {
      // there was a race and we lost
      delete source;
    }
  }
  return source_;
}


void KNodeParseEntry::perform() {
  // Note: this MUST run in the nodejs thread
  v8::HandleScope scope;

  // record rusage if enabled
  krusage_begin(rusage, "Parsing");

  // record document version
  uint64_t version = document_.version;

  // Export a copy of the document's current text state into V8 which will be
  // governed by the V8 GC.
  source(true);
  krusage_sample(rusage, "Copy document string");

  // get the v8 KDocument
  v8::Local<v8::Object> doc = [document_ v8Value]->ToObject();

  // find the parse function
  v8::Local<v8::Value> parseV = doc->Get(v8::String::New("parse"));
  //kassert(!parseV.IsEmpty());
  if (!parseV.IsEmpty() && parseV->IsFunction()) {
    // build arguments
    v8::Local<v8::Value> argv[] = {
      v8::String::NewExternal(source_),
      // Note that we convert ints to v8::Number with doubles since
      // v8::Integer is currently limited to 32-bit precision when created.
      // As soon as the v8::Integer::New accepts a 64-bit integer we can use
      // that instead.
      v8::Number::New((double)modificationIndex_),
      v8::Number::New((double)changeDelta_)
    };
    static const int argc = sizeof(argv) / sizeof(argv[0]);

    v8::TryCatch tryCatch;

    // call function
    v8::Local<v8::Value> returnValue =
        v8::Local<v8::Function>::Cast(parseV)->Call(doc, argc, argv);

    // check for error
    NSError *error = nil;
    if (tryCatch.HasCaught()) {
      v8::String::Utf8Value trace(tryCatch.StackTrace());
      const char *msg = NULL;
      if (trace.length() > 0) {
        msg = *trace;
      } else {
        msg = "(Unspecified exception)";
      }
      NSAutoreleasePool *pool = [NSAutoreleasePool new];
      h_atomic_barrier();
      WLOG("Error while executing parser for %@: %s", document_, msg);
      [pool drain];
    } else {
      // check results
      kassert(!returnValue.IsEmpty());
      kassert(returnValue->IsObject());

      // unwrap AST root object
      kod::ASTNodePtr astRoot =
          kod::ASTNodeWrapper::UnwrapNode(returnValue->ToObject());
      kassert(astRoot.get() != NULL);

      // mark parser return time
      krusage_sample(rusage, "Parser returned");

      // inform the document that the AST changed
      /*[document_ ASTWasUpdated:astRoot
                basedOnVersion:version
                    parseEntry:this];*/
    }

  } else DLOG("no parse() function available for document");

  // end rusage and dump report to stderr
  krusage_end(rusage, "KNodeIOEntry::perform() returning", "[rusage] ");

  KNodeIOEntry::perform();
}



//#define DEBUG_mergeWith 1
#if DEBUG_mergeWith
#define IFDEBUG_mergeWith(expr) do { expr }while(0)
#else
#define IFDEBUG_mergeWith(expr) ((void)0)
#endif

bool KNodeParseEntry::mergeWith(KNodeParseEntry *prev) {
  if (!prev)
    return true;

  NSUInteger &prev_index = prev->modificationIndex();
  NSInteger &prev_changeDelta = prev->changeDelta();
  NSUInteger &curr_index = modificationIndex_;
  NSInteger &curr_changeDelta = changeDelta_;

  #if DEBUG_mergeWith
  DLOG_EXPR(curr_index);
  DLOG_EXPR(prev_index);
  DLOG_EXPR(curr_changeDelta);
  DLOG_EXPR(prev_changeDelta);
  #endif

  // test 1: {'a',0,1} + {'ab',1,1} --> {'ab',0,2}
  if (curr_index > prev_index &&
      curr_changeDelta > 0 &&
      prev_changeDelta > 0) {
    IFDEBUG_mergeWith(NSLog(@"path 1 -- union (extend)"););
    // 'abc def ghi' >> {'abc def',0,4} + {'abc def ghi',7,4} -->
    //                        {'abc def ghi',0,11}
    curr_changeDelta += (curr_index - prev_index);
    curr_index = prev_index;
    return true;
  }

  // test 2: {'abc',2,1} + {'ab',2,-1} --> null
  if (curr_index == prev_index &&
      curr_changeDelta + prev_changeDelta == 0 &&
      curr_changeDelta < 0) {
    IFDEBUG_mergeWith(NSLog(@"path 2 -- noop"););
    return false;
  }

  // test 3: {'abc',2,1} + {'',3,-3} --> {'',2,-2}
  if (prev_changeDelta > -1) { // [0..
    IFDEBUG_mergeWith(NSLog(@"path 3 -- union (shrink)"););
    curr_changeDelta += prev_changeDelta;
    curr_index = prev_index;
    return true;
  }
  // else: prev_changeDelta < 0

  if (curr_index != prev_index) {
    // 'abc def ghi' >> {'abc def',7,-4} + {'def',0,-4} --> {'def',0,11}
    curr_changeDelta = (prev_index - prev_changeDelta);
  } else {
    // 'abc def ghi' >> {'abc  ghi',4,-3} + {'abc xyz123 ghi',4,6} --> {..,4,6}
  }
  IFDEBUG_mergeWith(NSLog(@"path 5 -- replace"););
  return true;
}
