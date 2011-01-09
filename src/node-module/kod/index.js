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
  exports.ASTNode = function () {}
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
