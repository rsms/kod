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
  console.log('kod.KDocument.prototype.parse');
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
  console.log('ast.children.length -> '+ast.children.length);
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

// String representation
Parser.prototype.toString = function() {
  return '<'+this.constructor.name+
         ' "'+this.name+'" ['+this.utis.join(', ')+']>';
};

// ----------------------------------------------------------------------------
// An very rudimentary "fallback" parser which divides a document into
// paragraphs and words.

function PlainTextParser() {
  Parser.call(this, 'Plain text', ['public.text']);
}
util.inherits(PlainTextParser, Parser);
exports.registerParser(new PlainTextParser);


// -------------------------------------------------------------
// tmp

function array_to_hash(a) {
  var ret = {};
  for (var i = 0; i < a.length; ++i)
    ret[a[i]] = true;
  return ret;
};

function HOP(obj, prop) {
  return Object.prototype.hasOwnProperty.call(obj, prop);
};

var WHITESPACE_CHARS = array_to_hash(" \n\r\t.,".split(''));
var EX_EOF = {};

/**
 * Parse a document
 */
PlainTextParser.prototype.parse = function (parseTask) {
  console.log(this+'.parse');

  // this is a stupid parser
  var astRoot = {kind:'root', children:[]};

  // split on words
  var source = parseTask.source,
      pos = 0, endPos = source.length, line = 0, col = 0,
      ch, tok = {}, newline_before;

  function peek() { return source.charAt(pos); };

  function is_digit(ch) { ch = ch.charCodeAt(0); return ch >= 48 && ch <= 57; }
  
  function is_word_char(ch) {
    return !HOP(WHITESPACE_CHARS, ch);
  };

  function skip_whitespace() {
    while (HOP(WHITESPACE_CHARS, peek())) next();
  }
  
  function start_token() {
    tok.line = line;
    tok.col = col;
    tok.pos = pos;
  }
  
  function token(kind, value) {
    if (value) {
      return {kind:kind, range:[pos, value.length]/*, value:value*/};
    } else {
      return {kind:kind};
    }
  }
  
  function next_token() {
    skip_whitespace();
    start_token();
    var ch = peek();
    if (!ch) return token("eof");
    return read_word();
    //parse_error("Unexpected character '" + ch + "'");
  }
  
  function next(signal_eof) {
    var ch = source.charAt(pos++);
    if (signal_eof && (!ch || pos === endPos))
      throw EX_EOF;
    if (ch == "\n") {
      newline_before = true;
      ++line;
      col = 0;
    } else {
      ++col;
    }
    return ch;
  }
  
  function read_while(pred) {
    var ret = "", ch = peek(), i = 0;
    while (ch && pred(ch, i++)) {
      ret += next();
      ch = peek();
    }
    return ret;
  }
  
  function read_word() {
    var word = read_while(is_word_char);
    return token("text.word", word)
  }
  
  while (1) {
    var t = next_token();
    if (!t || t.kind === 'eof')
      break;
    astRoot.children.push(t);
  }
  
  /*
  var pattern = new RegExp(/[\w]+/g);
  while (match = pattern.exec(parseTask.source)) {
    //console.log(match);
    astRoot.children.push({
      kind: 'text.word',
      range: [match.index, match[0].length]
    });
  }*/
  
  return astRoot;
};

// Helper function which can be used for testing during development of parsers
function simulateParsing(typeName, source, modificationIndex, changeDelta) {
  var doc = new kod.KDocument;
  doc.type = typeName;
  var ast = doc.parse(source, modificationIndex, changeDelta);
  return ast;
}

// Run a sample of the plain text parser when this module is run directly
if (module.id == '.') {
  var source = 'hello from the\ninternets';
  source = require('fs').readFileSync(
      '/Users/rasmus/src/kod/resources/about.md', 'utf8');
  var time = new Date;
  var ast = simulateParsing('public.text', source, 0, source.length);
  time = (new Date)-time;
  console.log('Real time spent: '+time+'ms');
  //console.log(util.inspect(ast, 0, 10));
}
