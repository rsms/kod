var sys = require('sys'),
    fs = require('fs'),
    spawn = require('child_process').spawn;

process.chdir(__dirname);

var stopOnFailure = true; // set to true to abort on first failure
var failcount = 0, runcount = 0;
var stderrWrite = process.binding('stdio').writeError;
var files = fs.readdirSync('.').filter(function(fn){
  return fn.match(/^test-.+\.js$/)
}).sort();
var totalcount = files.length;

function done() {
  sys.puts('>>> ran '+runcount+' of '+totalcount+' tests with '+
    failcount+' failure(s)');
  process.exit(failcount ? 1 : 0);
}

var stdoutSkipRe = /Unable to save file: (metadata|playlist)\.bnk/;

function runNext() {
  fn = files.shift();
  if (!fn || (stopOnFailure && failcount)) return done();
  console.log('>>> run '+fn);
  var nodebin = process.argv[0];
  var args = [fn];
  var child = spawn(nodebin, args);
  child.stdin.end();
  child.stdout.on('data', function (data){
    if (!stdoutSkipRe.test(data))
      process.stdout.write(data);
  });
  child.stderr.on('data', function (data) {
    if (data.length >= 7 && data.toString('ascii', 0, 7) === 'execvp(') {
      console.error('>>> fail '+fn+' -- execvp('+sys.inspect(nodebin)+
        ', '+sys.inspect(args)+') failed: '+data.toString('utf8'));
    } else {
      stderrWrite(data);
    }
  });
  child.on('exit', function (code) {
    if (code !== 0) {
      console.log('>>> fail '+fn+' -- status '+code);
      failcount++;
    } else {
      console.log('>>> ok '+fn);
    }
    runcount++;
    runNext();
  });
}

console.log('>>> running '+files.length+' tests');
runNext();
