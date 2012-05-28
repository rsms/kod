// -*- Mode: Node.js JavaScript tab-width: 4 -*-
var textparser = require('./')

var LOREM = 'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.\n\
Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.\n\
Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.\n\
Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.'


function parse(source){
	// TODO: Use benchmark.js instead
	var time = +new Date
	
	root = textparser.Parser.simulate('public.text', source, 0, source.length)
	
	time = +new Date - time
	console.log('Parse time: '+time+'ms')
	return root
}


exports.setup = function(){}
exports.teardown = function(){}


exports['test existance'] = function(test){
	var root = parse('hello from the\ninternets 98 years old\n\nwhat do you think?')
	test.ok(root)
}

exports['test root node'] = function(test){
	var root = parse('hello')
	test.ok(root, "The AST wasn't returned by the parser")
	test.equal('root', root.kind)
	test.ok(!root.parentNode)
	test.ok(root.childNodes)
	test.ok(root.childNodes.length)
}

exports['test root childNodes'] = function(test){
	var root = parse('testing\n1\n2\n3')
	test.equal(4, root.childNodes.length, "wrong number of childNodes")
}

exports['test paragraph'] = function(test){
	var root = parse(LOREM)
	test.equal(4, root.childNodes.length, "wrong number of childNodes")
	
	for (var i = -1, childNode; childNode = root.childNodes[++i];){
		test.ok(childNode, "childNode must exist")
		test.equal("text.paragraph", childNode.kind, "first level elements must be paragraphs")
		test.equal(root, childNode.parentNode, "children need parents")
		test.ok(childNode.childNodes.length > 0, "paragraphs must have words")
	}
	// var util = require('util')
	// console.log(util.inspect(root, 3, 4))
}


// TODO: Use an async test framework. Vows?
// You should be able to run a single file that requires and runs all the tests from all tests
exports.run = function(){
	var assert = require('assert')
	var testState
	var errors = []
	
	for (var testName in exports) if (testName.indexOf('test') != -1){
		testState = {}
		console.log("\n"+testName)
		try {
			exports.setup.call(testState)
			exports[testName].call(testState, assert)
		}
		catch(e){
			console.log(testName, e.stack)
			errors.push(e)
		}
		finally {
			exports.teardown.call(testState)
			testState = null
		}
	}
	return errors.length
}

if (module.id == '.') process.exit(exports.run());
