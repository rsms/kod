var util = require('util');
var kod = require('../');
var textparser = require('./');

// An rudimentary "fallback" parser which divides a document into paragraphs and
// words.

function PlainTextParser() {
  textparser.Parser.call(this, 'Plain text', ['public.text']);
}
util.inherits(PlainTextParser, textparser.Parser);
textparser.registerParser(new PlainTextParser);

// -------------------------------------------------------------

var debug = false;


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

PlainTextParser.prototype.tokenizer = function (source, startOffset, length) {
  // split on words
  var pos = startOffset || 0,
      endPos = source.length,
      line = 0, col = 0,
      ch, tok = {}, newline_before;

  if (typeof length === 'number')
    endPos = Math.min(endPos, length);

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
  
  function token(kind, length) {
    var t = {
      kind: kind,
      location: tok.pos,
      length: length,
      newline: newline_before,
      //value: source.substr(tok.pos, length)
    }
    // reset
    newline_before = false;
    return t;
  }
  
  function next_token() {
    skip_whitespace();
    start_token();
    var ch = peek();
    if (!ch) throw EX_EOF;
    return read_word();
  }
  
  function next(signal_eof) {
    var ch = source.charAt(pos++);
    if (signal_eof && (!ch || pos === endPos)) {
      throw EX_EOF;
    }
    if (ch === "\n") {
      newline_before = true;
      ++line;
      col = 0;
    } else {
      ++col;
    }
    return ch;
  }
  
  function read_while(pred) {
    var ch = peek(), i = 0;
    while (ch && pred(ch, i++)) {
      next();
      ch = peek();
    }
  }
  
  function read_word() {
    var pos1 = pos;
    read_while(is_word_char);
    return token("text.word", pos-pos1);
  }
  
  return function() {
    try {
      return next_token();
    } catch (e) {
      if (e === EX_EOF) {
        return null;
      }
      throw e;
    }
  }
};


/**
 * Parse a document
 */
PlainTextParser.prototype.parse = function (parseTask) {
  //console.log(this+'.parse');

  var source = parseTask.source;
  var nextToken = this.tokenizer(source);
  var token, peekedToken, prevToken, parentNode;
  var s_location = 0, s_absloc = 0;
  var parentSourceLocation = 0;
  
  // token feed
  function peek() { return peekedToken || (peekedToken = input()); }
  function next() {
    prevToken = token;
    if (peekedToken) {
      token = peekedToken;
      peekedToken = null;
    } else {
      token = nextToken();
    }
    //console.log('next token: '+util.inspect(token,0,2))
    return token;
  }
  function prev() { return prevToken; }
  
  // token test
  function is(type, val) {
    return token &&
           token.type === type &&
           (val == undefined || token.value === val);
  }
  
  // create an AST node
  function astnode (kind) {
    return new kod.ASTNode(kind,
      /* sourceLocation*/  token.location - parentSourceLocation,
       /* sourceLength */  token.length,
                           parentNode);
  }
  
  // statements
  function unexpected(tok) {
    if (!tok) tok = token;
    return astnode('error.unexpected');
  }
  function word() {
    if (!token || token.kind !== 'text.word')
      return unexpected();
    var word = astnode('text.word');
    if (debug)
      word._value = source.substr(token.location, token.length);
    next();
    return word;
  }
  function paragraph() {
    var node = astnode('text.paragraph');

    // push
    var parentParentSourceLocation = parentSourceLocation;
    var parentParentNode = parentNode;
    parentSourceLocation = token.location;
    parentNode = node;

    while (token) {
      if (token.newline) {
        // break here and have statement() call paragraph() again
        token.newline = false;
        break;
      } else {
        node.pushChild(word());
      }
    }

    // update length
    node.sourceLength =
        (token ? token.location-1 : source.length) - parentSourceLocation;

    // pop
    parentNode = parentParentNode;
    parentSourceLocation = parentParentSourceLocation;

    return node;
  }
  function statement() {
    switch (token.kind) {
      case "text.word":
        return paragraph();
      default:
        return unexpected();
    }
  }

  // ignite
  token = next();
  var rootNode = parentNode = astnode('root');
  while (token) {
    rootNode.pushChild(statement());
  }

  // dump the AST (warning -- might be VERY SLOW)
  console.log(util.inspect(parentNode, 0, 10));

  return parentNode;
};

// TODO: clean up this mess and make a ./util.js package with universal
// tokenization and grammar support functions

// Run a sample of the plain text parser when this module is run directly
if (module.id == '.') {
  //debug = true;
  //var source = require('fs').readFileSync('/Users/rasmus/src/kod/resources/about.md', 'utf8');
  source = 'hello from the\ninternets 98 years old\n\nwhat do you think?';
  var time = new Date;
  var ast = textparser.Parser.simulate('public.text', source, 0, source.length);
  time = (new Date)-time;
  console.log('Real time spent: '+time+'ms');
}
