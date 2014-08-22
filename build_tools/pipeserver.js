/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

/**
 * PipeServer allows for creation of a server that listens on two ports, echoing
 * all input from each port to the other. The server persists until all clients
 * on one side close their connections.
 *
 * Example usage:
 * PipeServer.pipe().then(function(ports) {
 *   console.log('Server established at ports %d and %d.', ports[0], ports[1]);
 * });
 */
var PipeServer = {};
/**
 * The host name on which to run the TCP server.
 * @const
 */
PipeServer.HOST = '127.0.0.1';

/**
 * This is the PPAPI error code for a TCP FIN.
 * @type {number}
 */
PipeServer.ERROR_CODE_FIN = -100;

/**
 * This function is a no-op. This is passed as a callback when we don't
 * listen to the result.
 * @private
 */
PipeServer.noop_ = function() { };

/**
 * A PipeSocket keeps state about a socket and the clients connected to it.
 * @private
 */
PipeServer.PipeSocket_ = function(port, server) {
  this.port = port || null;
  this.server = server || null;
  this.clients = {};
};

/**
 * Find a valid port and create a server on that port.
 * @private
 * @returns {Promise}
 */
PipeServer.createServer_ = function() {
  return new Promise(function(resolve, reject) {
    chrome.sockets.tcpServer.create({}, function(createInfo) {
      var socketId = createInfo.socketId;
      chrome.sockets.tcpServer.listen(socketId, PipeServer.HOST, 0, onListen);
      function onListen(resultCode) {
        if (resultCode < 0) {
          reject(new Error('listen() error: ' + resultCode));
          return;
        }
        chrome.sockets.tcpServer.getInfo(socketId, function(info) {
          resolve(new PipeServer.PipeSocket_(info.localPort, socketId));
        });
      }
    });
  });
};

/**
 * Given two sockets, redirect all input from one socket to all clients
 * connected to the other socket.
 * @private
 * @param {PipeServer.PipeSocket_} from The socket that receives input.
 * @param {PipeServer.PipeSocket_} to The socket that broadcasts output.
 */
PipeServer.redirect_ = function(from, to) {
  var tcp = chrome.sockets.tcp;
  var tcpServer = chrome.sockets.tcpServer;

  tcpServer.onAccept.addListener(onAccept);
  function onAccept(info) {
    if (info.socketId !== from.server) {
      return;
    }

    var client = info.clientSocketId;

    function onReceive(info) {
      if (info.socketId !== client) {
        return;
      }
      // Broadcast received message to everyone connected to the other port.
      for (var destinationStr in to.clients) {
        var destination = parseInt(destinationStr);
        tcp.send(destination, info.data, PipeServer.noop_);
      }
    }
    function onReceiveError(info) {
      if (info.socketId !== client) {
        return;
      }
      // Handle a TCP FIN (connection closed).
      if (info.resultCode === PipeServer.ERROR_CODE_FIN) {
        delete from.clients[client];
        tcp.onReceive.removeListener(onReceive);
        tcp.onReceiveError.removeListener(onReceiveError);
        // If all connections on one side have been closed, close everything
        // else as well and shut down the server.
        if (Object.keys(from.clients).length === 0 ||
            Object.keys(to.clients).length === 0) {
          deleteServer();
        }
      } else {
        console.log('receive error: ' + info.resultCode);
      }
    }

    tcp.onReceive.addListener(onReceive);
    tcp.onReceiveError.addListener(onReceiveError);

    // Keep track of the handlers so we can remove them when we shut down
    // the server.
    from.clients[client] = {
      onReceive: onReceive,
      onReceiveError: onReceiveError
    };
    tcp.setPaused(client, false);
  }

  function deleteServer() {
    function disconnectAll(clients) {
      for (var clientStr in clients) {
        var clientId = parseInt(clientStr);
        tcp.onReceive.removeListener(clients[clientId].onReceive);
        tcp.onReceiveError.removeListener(clients[clientId].onReceiveError);
        tcp.close(clientId, PipeServer.noop_);
        delete clients[clientId];
      }
    }
    disconnectAll(from.clients);
    disconnectAll(to.clients);
    tcpServer.onAccept.removeListener(onAccept);
    tcpServer.close(from.server, PipeServer.noop_);
    tcpServer.close(to.server, PipeServer.noop_);
  }
};

/**
 * Create a TCP server that echoes all input from one port to another
 * port.
 * @returns {Promise} A Promise that resolves with the port numbers.
 */
PipeServer.pipe = function() {
  var socket1, socket2;
  return Promise.resolve().then(function() {
    return PipeServer.createServer_();
  }).then(function(socket) {
    socket1 = socket;
    return PipeServer.createServer_()
  }).then(function(socket) {
    socket2 = socket;
    PipeServer.redirect_(socket1, socket2);
    PipeServer.redirect_(socket2, socket1);
    return [socket1.port, socket2.port];
  }).catch(function(err) {
    if (socket1) {
      chrome.sockets.tcpServer.close(socket1.server, PipeServer.noop_);
    }
    if (socket2) {
      chrome.sockets.tcpServer.close(socket2.server, PipeServer.noop_);
    }
    throw err;
  });
};
