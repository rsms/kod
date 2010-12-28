// common stuff used by tests
var assert = require('assert');
var sys = require('sys');
var kod = require('../kod');

// make these modules available to any module which require()s this module
GLOBAL.sys = sys;
GLOBAL.assert = assert;
GLOBAL.kod = kod;
GLOBAL.dump = function () {
  return sys.error(sys.inspect.apply(sys, 
    Array.prototype.slice.call(arguments)));
}

process.on('uncaughtException', function (err) {
  console.error(err.stack || err);
  process.exit(2);
});
