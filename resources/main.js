var net = require('net');
var util = require('util');
var kod = new process.EventEmitter(); // TODO: should be a module in the future

// xxx dev
kod.emit = function() {
  var args = Array.prototype.slice.call(arguments);
  console.log('kod.emit(%j)', args);
  return process.EventEmitter.prototype.emit.apply(this, args);
}

function Channel(name, fd) {
  net.Stream.call(this, fd, "unix");
  this.name = name;
  this.recvStrBuf = '';
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
  this.send('hello'); // handshake confirmation
  /*var self = this;
  setInterval(function(){
    self.send({type:'event', name:'beacon', data:(new Date).getTime()/1000.0});
  }, 1000);*/
  console.log('onOpen');
}

Buffer.prototype.indexOf = function(byteValue, offset) {
  offset = offset ? offset : 0;
  var index = offset, length = this.length-offset;
  while (index < length && this[index] != byteValue) { ++index; }
  return index == length ? -1 : index;
}

Channel.prototype.onData = function (data) {
  //console.log('[channel %j] received %d bytes', this.name, data.length);
  var offset = 0;
  while (true) {
    // find null
    var nullIndex = data.indexOf(0, offset);
    if (nullIndex != -1) {
      // we have a complete message
      this.recvStrBuf += data.toString('utf8', offset, nullIndex);
      try {
        var message = JSON.parse(this.recvStrBuf);
        this.onMessage(message);
      } catch (e) {
        console.error(this+' failed to parse received data as JSON %s\n%j', e,
                      this.recvStrBuf);
      }
      this.recvStrBuf = '';
      // continue and find next chunk
      offset = nullIndex+1;
      if (offset == data.length)
        break;
    } else {
      // no sentinel (partial data)
      //console.log('[channel %j] partial data', this.name);
      this.recvStrBuf += data.toString('ascii', offset);
      break;
    }
  }
}

Channel.prototype.sendResponse = function (request, data) {
  response = {
    type: 'response',
    rtag: request.rtag
  };
  if (data !== undefined)
    response.data = data;
  this.send(response);
}

Channel.prototype.onMessage = function (message) {
  console.log('[channel %j] received message: %j', this.name, message);
  if (message.type === 'event') {
    if (message.name) {
      kod.emit(message.name);
      if (message.rtag) this.sendResponse(message);
    }
  } //else if (message.type === 'method') {
  else if (message.rtag) {
    this.sendResponse(message, {
      error:'invalid message type "'+message.type+'"'
    });
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
