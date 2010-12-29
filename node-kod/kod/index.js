var binding = require('./binding');
module.exports = exports = new process.EventEmitter();
Object.keys(binding).forEach(function(k){ exports[k] = binding[k]; });

function exposeGetter(name, fun) {
  Object.defineProperty(exports, name, {get: fun});
}

exposeGetter("allDocuments", exports.getAllDocuments);

// install last line of defence for exceptions to avoid node crashing Kod.app
process.on('uncaughtException', function (err) {
  exports.handleUncaughtException(err);
});
