var net = require('net');
var util = require('util');

function Channel(name, fd) {
  net.Stream.call(this, fd, "unix");
  this.name = name;
  this.recvbuf = new Buffer(0);
  this.on('data', this.onData);
}
util.inherits(Channel, net.Stream);
Channel.openChannels = {};

Channel.prototype.send = function(obj) {
  var jsonstr = JSON.stringify(obj);
  var buf = new Buffer(jsonstr.length+1);
  buf.asciiWrite(jsonstr);
  buf[jsonstr.length] = 0;
  return this.write(buf);
};

Channel.prototype.onOpen = function () {
  this.send('hello');
  var self = this;
  setInterval(function(){
    self.send({ id: 'beacon', time: (new Date).getTime()/1000.0 });
  }, 1000);
  console.log('onOpen');
}

Channel.prototype.onData = function (data) {
  // TODO: Fill this.recvbuf and watch for null-terminated chunks which should
  //       be considered complete messages
  
  try {
    var message = JSON.parse(data.asciiSlice(0, data.length));
    console.log('[channel %j] received: %j', this.name, message);
    //this.send({pong:message});
  } catch (e) {
    console.error(this+' failed to parse data %j', data);
  }
}


var stdin = new net.Stream(0, 'unix');
var channelName = null;
stdin.on('data', function (data) {
  channelName = null;
  if (data.length < 256) {
    var str = data.toString('utf8');
    if (str.indexOf("openchannel:") == 0) {
      //console.log('data received on stdin: %j', str);
      channelName = str.substr(("openchannel:").length);
      if (!channelName.match(/^[\w\._-]+$/))
        channelName = null;
    }
  }
});
stdin.on('fd', function (fd) {
  // ignore fds w/o name
  if (!channelName)
    return;
  var channel = new Channel(channelName, fd);
  if (Channel.openChannels[channel.name]) {
    channel.resume();
    channel.write('channel already registered');
    process.nextTick(function(){ channel.end(); });
  } else {
    //console.log('opened channel %s on fd %d', channel.name, fd);
		Channel.openChannels[channel.name] = channel;
		channel.on('end', function() {
		  Channel.openChannels[channel.name] = null;
		});
		channel.onOpen();
		channel.resume();
  }
});
stdin.resume();
//console.log('waiting for FD to arrive on stdin');
