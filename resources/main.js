var util = require('util');
var kod = require('kod');

console.log('main.js started. kod -> '+util.inspect(kod));

kod.exposedFunctions['foo'] = function(callback) {
  console.log('external function "foo" called with %s', util.inspect(callback));
  if (callback)
    callback(null, {"bar":[1,2,3.4,"mos"],"grek en":"hoppär"});
}

// dump kod.allDocuments every 10 sec
setInterval(function(){
  //console.log("kod.allDocuments -> "+util.inspect(kod.allDocuments));
  //kod.allDocuments[0].hasMetaRuler = true;
}, 10000);

