//
// Entry point for the main Kod nodejs thread
//

// install last line of defence for exceptions to avoid nodejs killing Kod.app
process.on('uncaughtException', global._kod.handleUncaughtException);

// TODO: alter behavior of process.exit

// add our built-in module path to the front of require.paths
require.paths.unshift(require.paths.pop());

// load any user bootstrap script
var userModule = null;
try { userModule = require(process.env.HOME + '/.kod'); } catch (e) {}


// ----------------------------------------------------------------------------
// Things below this line is only used for development and debugging and not
// really meant to be in this file

/*if (typeof gc === 'function') {
  // if we are running with --expose_gc, force collection at a steady interval.
  // Note: this is a serious performance killer and only used for debugging
  setInterval(gc, 10000);
}*/

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

kod.on('openDocument', function(document) {
  //console.log('openDocument: '+ util.inspect(document, 0, 4));
  console.log('openDocument: '+document.identifier+' '+document.url);
});

// example event listener for the "activateDocument" event, emitted when a
// document becomes selected (when the selection changes)
kod.on('activateDocument', function(document) {
  // Dump document -- includes things like the word dictionary. Massive output.
  //console.log('activateDocument: '+util.inspect(document, 0, 4));
  console.log('activateDocument: '+document.identifier+' '+document.url);

  // As document objects are persistent, we can add properties to it which will
  // survive as long as the document is open
  var timeNow = (new Date()).getTime();
  if (document.lastSeenByNode) {
    console.log('I saw this document '+
                ((timeNow - document.lastSeenByNode)/1000)+
                ' seconds ago');
  }
  document.lastSeenByNode = timeNow;

  // Replace the contents of the document:
  //document.text = "Text\nreplaced\nby main.js";
});

kod.on('closeDocument', function(document, docId) {
  //console.log('closeDocument: ['+docId+'] '+ util.inspect(document, 0, 4));
  console.log('closeDocument: '+document.identifier+' '+document.url);
});

// dump kod.allDocuments every 10 sec
/*setInterval(function(){
  //console.log("kod.allDocuments -> "+util.inspect(kod.allDocuments));
  //kod.allDocuments[0].hasMetaRuler = true;
}, 10000);*/
