var events = require('events');

// set the "kod" module to the object created by kod-core (_kod)
module.exports = exports = global._kod;

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
