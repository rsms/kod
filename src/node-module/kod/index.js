module.exports = exports = global._kod;

function exposeGetter(name, fun) {
  Object.defineProperty(exports, name, {get: fun});
}
exposeGetter("allDocuments", exports.getAllDocuments);

// install last line of defence for exceptions to avoid node crashing Kod.app
process.on('uncaughtException', exports.handleUncaughtException);
