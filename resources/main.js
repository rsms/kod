//
// Entry point for the main Kod nodejs thread
//

// install last line of defence for exceptions to avoid nodejs killing Kod.app
process.on('uncaughtException', global._kod.handleUncaughtException);

// add our built-in module path to the front of require.paths
require.paths.unshift(require.paths.pop());

// load any user bootstrap script
var userModule = null;
try { userModule = require(process.env.HOME + '/.kod'); } catch (e) {}


// ----------------------------------------------------------------------------
// Things below this line is only used for development and debugging and not
// really meant to be in this file

// debug
var util = require('util');
var kod = require('kod');
console.log('main.js started. kod -> '+util.inspect(kod));
console.log('process.env -> '+util.inspect(process.env));
console.log('require.paths -> '+util.inspect(require.paths));

// example exposed method which can be called from Kod using the
// KNodeInvokeExposedJSFunction function.
kod.exposedFunctions.foo = function(callback) {
  console.log('external function "foo" called with %s', util.inspect(callback));
  if (callback)
    callback(null, {"bar":[1,2,3.4,"mos"],"grek en":"hoppär"});
}

// example event listener for the "tabDidBecomeSelected" event, emitted when a
// document becomes selected (when the selection changes)
kod.on('tabDidBecomeSelected', function(document) {
  //console.log('tabDidBecomeSelected: '+util.inspect(document));

  // Replace the contents of the document:
  //document.text = "Text\nreplaced\nby main.js";
});

// dump kod.allDocuments every 10 sec
/*setInterval(function(){
  //console.log("kod.allDocuments -> "+util.inspect(kod.allDocuments));
  //kod.allDocuments[0].hasMetaRuler = true;
}, 10000);*/
