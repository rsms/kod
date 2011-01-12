// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

var events = require('events');

// set the "kod" module to the object created by kod-core (_kod)
if (global._kod) {
  module.exports = exports = global._kod;
} else {
  // we are being run outside of kod
  exports.outsideOfKod = true;
}

// inherit from EventEmitter
for (var k in events.EventEmitter.prototype) {
  exports.__proto__[k] = events.EventEmitter.prototype[k];
}
events.EventEmitter.call(exports);

// Local function for conveniently exposing a getter
function exposeGetter(name, fun) {
  Object.defineProperty(exports, name, {get: fun});
}
exposeGetter("allDocuments", exports.getAllDocuments);

// ----------------------------------------------------------------------------

// If we are not running in kod, setup some dummy constructors
if (exports.outsideOfKod) {
  exports.KDocument = function () {};
  
  // this is a rather special thing when running live -- it's a data structure
  // shared with other parts of Kod and is not managed by V8 and its GC.
  exports.ASTNode = function (kind, sourceLocation, sourceLength, parentNode) {
    this.kind = kind;
    this.sourceLocation = sourceLocation;
    this.sourceLength = sourceLength;
    if (parentNode)
      this.parentNode = parentNode;
  }
  exports.ASTNode.prototype.pushChild = function (node) {
    if (!this.childNodes) this.childNodes = [node];
    else this.childNodes.push(node);
  }
}

// toString
// <KDocument #123 "basictypes.h" [public.c-header] "file://...">
exports.KDocument.prototype.toString = function(){
  var url = this.url;
  return '<KDocument #'+this.identifier+
         ' "'+this.title+'" ['+this.type+']'+
         (url ? ' "'+url+'"' : '')+
         '>';
}
