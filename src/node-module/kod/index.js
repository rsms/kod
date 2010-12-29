module.exports = exports = global._kod;

// exposedFunctions is managed by _kod.exposedFunctions, thus we need to support
// setting the value (i.e. kod.exposedFunctions = {})
/*_kod.exposedFunctions = {};
Object.defineProperty(exports, "exposedFunctions", {
  get: function(){ return _kod.exposedFunctions; },
  set: function(v){ _kod.exposedFunctions = v; }
});*/

// export everything on _kod to exports
/*Object.keys(_kod).forEach(function(k){
  //if (!(k in exports))
    exports[k] = _kod[k];
});*/

function exposeGetter(name, fun) {
  Object.defineProperty(exports, name, {get: fun});
}
exposeGetter("allDocuments", exports.getAllDocuments);

//exports.externalFunctions = {};

// install last line of defence for exceptions to avoid node crashing Kod.app
process.on('uncaughtException', function (err) {
  exports.handleUncaughtException(err);
});
