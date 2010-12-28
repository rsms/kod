var util = require('util');
var kod = require('kod');

console.log('main.js started. kod -> '+util.inspect(kod));

kod.externalFunctions['foo'] = function(callback) {
  console.log('external function "foo" called with %s', util.inspect(callback));
  if (callback)
    callback(null, {"bar":[1,2,3.4,"mos"],"grek en":"hoppär"});
}

setInterval(function(){
  console.log("kod.allDocuments -> "+util.inspect(kod.allDocuments));
}, 1000); // keepalive

