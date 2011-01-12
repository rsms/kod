var kod = require('..');
var util = require('util');

// maps UTI -> list of parsers
var parsers = {};

// register a parser
function registerParser(parser) {
  if (!Array.isArray(parser.utis))
    throw new Error('parser.utis must be an array of UTIs');
  parser.utis.forEach(function (uti) {
    uti = uti.toLowerCase(); // normalize case
    var parserForUTI = parsers[uti];
    if (!parserForUTI) {
      parsers[uti] = [parser];
    } else {
      if (parserForUTI.indexOf(parser) === -1)
        parserForUTI.push(parser);
    }
  });
}
exports.registerParser = registerParser;


// unregister a parser
function unregisterParser(parser) {
  for (var k in parsers) {
    var parserForUTI = parsers[k];
    if (parserForUTI) {
      for (var i=0,L=parserForUTI.length; i<L; ++i) {
        var registeredParser = parserForUTI[i];
        if (registeredParser === parser) {
          delete parserForUTI[i];
          --i; // since we removed one
        }
      }
      // if we removed all parser for a uti, dispose of the now empty array
      if (parserForUTI.length == 0)
        parsers[k] = null;
    }
  }
}
exports.unregisterParser = unregisterParser;


/**
 * Retrieve a list of parsers which are able to handle the UTI. The returned
 * list is ordered by priority.
 * This has a O(log n) complexity and is thus very efficient.
 */
function parsersForUTI(uti) {
  return parsers[uti];
}
exports.parsersForUTI = parsersForUTI;


// add a textParser function to KDocument
kod.KDocument.prototype.textParser = function() {
  var parsers = parsersForUTI(this.type);
  return parsers ? parsers[0] : null;
};

kod.KDocument.prototype.parse =
    function (source, modificationIndex, changeDelta) {
  //console.log('kod.KDocument.prototype.parse');
  /*var parser, parsers = parsersForUTI(this.type);
  if (!parsers || !(parser = parsers[0])) {
    console.warn('[document.parse] no matching parser found for '+this);
    return;
  }*/
  // while developing...
  var parser = parsersForUTI('public.text')[0];
  var parseTask = new ParseTask(this, source, modificationIndex, changeDelta);
  var ast = parser.parse(parseTask);
  //console.log(util.inspect(ast, 0, 10));
  //console.log('ast.children.length -> '+ast.children.length);
  return ast;
}

//console.log("textparser enabled. "+util.inspect(kod.KDocument.prototype));

// ----------------------------------------------------------------------------
// represents a "parse this please" task send to a parser

function ParseTask(document, source, modificationIndex, changeDelta) {
  this.document = document;
  this.source = source;
  this.modificationIndex = modificationIndex;
  this.changeDelta = changeDelta;
  this.diagnostics = [];
}

// ----------------------------------------------------------------------------
// base prototype for parsers

function Parser(name, utis) {
  // human-readable name of this parser
  this.name = name;

  // priority-ordered list of UTI this parser can handle
  this.utis = utis;
}
exports.Parser = Parser;


Parser.prototype.parse = function (parseTask) {
  throw new Error('not implemented');
}

// String representation
Parser.prototype.toString = function() {
  return '<'+this.constructor.name+
         ' "'+this.name+'" ['+this.utis.join(', ')+']>';
};


// Helper function which can be used for testing during development of parsers
function simulate(typeName, source, modificationIndex, changeDelta) {
  var doc = new kod.KDocument;
  doc.type = typeName;
  var ast = doc.parse(source, modificationIndex, changeDelta);
  return ast;
}
Parser.simulate = simulate;

require('./plaintext');
