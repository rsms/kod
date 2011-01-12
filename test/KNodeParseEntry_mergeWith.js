var assert = require('assert');

/*
 * This test was written while developing the edit entry merge algorithm and
 * serves as the canonical implementation of KNodeParseEntry::mergeWith()
 */

function mergeEdits(prev, curr) {
  console.log('\n%j\n%j', prev, curr)
  // test 1: {'a',0,1} + {'ab',1,1} --> {'ab',0,2}
  if (curr.index > prev.index &&
      curr.changeDelta > 0 &&
      prev.changeDelta > 0) {
    console.log('path 1 -- union (extend)');
    
    // 'abc def ghi' >> {'abc def',0,4} + {'abc def ghi',7,4} -->
    //                        {'abc def ghi',0,11}
    
    curr.changeDelta += (curr.index - prev.index);
    curr.index = prev.index;
    return curr;
  }
  
  // test 2: {'abc',2,1} + {'ab',2,-1} --> null
  if (curr.index === prev.index &&
      curr.changeDelta + prev.changeDelta === 0 &&
      curr.changeDelta < 0) {
    console.log('path 2 -- noop');
    return null;
  }
  
  // test 3: {'abc',2,1} + {'',3,-3} --> {'',2,-2}
  if (prev.changeDelta > -1) { // [0..
    console.log('path 3 -- union (shrink)');
    curr.changeDelta += prev.changeDelta;
    curr.index = prev.index;
    return curr;
  }
  // else: prev.changeDelta < 0
  
  if (curr.index !== prev.index) {
    // 'abc def ghi' >> {'abc def',7,-4} + {'def',0,-4} --> {'def',0,11}
    curr.changeDelta = (prev.index - prev.changeDelta);
  } else {
    // 'abc def ghi' >> {'abc  ghi',4,-3} + {'abc xyz123 ghi',4,6} --> {..,4,6}
  }
  console.log('path 5 -- replace');
  
  return curr;

  return 'NOMATCH';
}

// test 1: union (extend)
assert.deepEqual(mergeEdits(
  //      ''
  {source:'a', index:0, changeDelta:1},
  {source:'ab', index:1, changeDelta:1}
),{source:'ab', index:0, changeDelta:2});
assert.deepEqual(mergeEdits(
  {source:'abcdef', index:2, changeDelta:4},
  {source:'abcdefgh', index:6, changeDelta:2}
),{source:'abcdefgh', index:2, changeDelta:6});

// test 2: no-op
assert.equal(mergeEdits(
  //      'ab'
  {source:'abc', index:2, changeDelta:1},
  {source:'ab', index:2, changeDelta:-1}
), null);

// test 3: union (shrink)
assert.deepEqual(mergeEdits(
  //      'ab'
  {source:'abc', index:2, changeDelta:1},
  {source:'', index:3, changeDelta:-3}
),{source:'', index:2, changeDelta:-2});

// test 4: union (shrink) -- enter "c", then replace "c" with "i"
assert.deepEqual(mergeEdits(
  //      'ab'
  {source:'abc', index:2, changeDelta:1},
  {source:'abi', index:2, changeDelta:0}
),{source:'abi', index:2, changeDelta:1});

// test 5: replace (delete "abc", then insert "xyz123")
assert.deepEqual(mergeEdits(
  //      'abc'
  {source:'', index:3, changeDelta:-3},
  {source:'xyz123', index:0, changeDelta:6}
),{source:'xyz123', index:0, changeDelta:6});

// test 6: replace (delete "def", then insert "xyz123")
assert.deepEqual(mergeEdits(
  //      'abc def ghi'
  {source:'abc  ghi', index:4, changeDelta:-3},
  {source:'abc xyz123 ghi', index:4, changeDelta:6}
),{source:'abc xyz123 ghi', index:4, changeDelta:6});

// test 7: replace (delete " ghi", then delete "abc ")
// This should effectively result in a "replace" compound operation, replacing
// "abc def ghi" with "def".
assert.deepEqual(mergeEdits(
  //      'abc def ghi'
  {source:'abc def', index:7, changeDelta:-4},
  {source:'def', index:0, changeDelta:-4}
),{source:'def', index:0, changeDelta:11});
// union (extend)
assert.deepEqual(mergeEdits(
  {source:'abc def', index:0, changeDelta:4}, // insert 'abc '
  {source:'abc def ghi', index:7, changeDelta:4} // insert ' ghi'
),{source:'abc def ghi', index:0, changeDelta:11});

// test 8: -- replace "c" with "E", then replace "E" with "k"
assert.deepEqual(mergeEdits(
  //      'abc'
  {source:'abE', index:2, changeDelta:0},
  {source:'abk', index:2, changeDelta:0}
),{source:'abk', index:2, changeDelta:0});

// test 9: union (shrink)
assert.deepEqual(mergeEdits(
  //      'abc'
  {source:'abXYZ', index:2, changeDelta:2},
  {source:'abX', index:3, changeDelta:-2}
),{source:'abX', index:2, changeDelta:0});

// test 10:  'int foo() {}'  -->  'int foo(int bar) {}'
assert.deepEqual(mergeEdits(
  {source:'int foo(i) {}', index:8, changeDelta:1},
  {source:'int foo(in) {}', index:9, changeDelta:1}
),{source:'int foo(in) {}', index:8, changeDelta:2});
assert.deepEqual(mergeEdits(
  {source:'int foo(in) {}', index:8, changeDelta:2},
  {source:'int foo(int) {}', index:10, changeDelta:1}
),{source:'int foo(int) {}', index:8, changeDelta:3});
assert.deepEqual(mergeEdits(
  {source:'int foo(int) {}', index:8, changeDelta:3},
  {source:'int foo(int ) {}', index:11, changeDelta:1}
),{source:'int foo(int ) {}', index:8, changeDelta:4});
assert.deepEqual(mergeEdits(
  {source:'int foo(int) {}', index:8, changeDelta:4},
  {source:'int foo(int b) {}', index:12, changeDelta:1}
),{source:'int foo(int b) {}', index:8, changeDelta:5});
assert.deepEqual(mergeEdits(
  {source:'int foo(int) {}', index:8, changeDelta:5},
  {source:'int foo(int ba) {}', index:13, changeDelta:1}
),{source:'int foo(int ba) {}', index:8, changeDelta:6});
assert.deepEqual(mergeEdits(
  {source:'int foo(int) {}', index:8, changeDelta:6},
  {source:'int foo(int bar) {}', index:14, changeDelta:1}
),{source:'int foo(int bar) {}', index:8, changeDelta:7});

// test 11
assert.deepEqual(mergeEdits(
  {source:'ab', index:1, changeDelta:1},
  {source:'abc', index:2, changeDelta:1}
),{source:'abc', index:1, changeDelta:2});













