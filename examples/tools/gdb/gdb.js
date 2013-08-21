/*
 * Copyright (c) 2013 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

'use strict';

lib.rtdep('lib.f',
          'hterm');

// CSP means that we can't kick off the initialization from the html file,
// so we do it like this instead.
window.onload = function () {
  lib.init(function() {
    Gdb.init();
  });
}

/**
 * The Gdb-powered terminal command.
 *
 * This class defines a command that can be run in an hterm.Terminal instance.
 *
 * @param {Object} argv The argument object passed in from the Terminal.
 */
function Gdb(argv) {
  this.argv_ = argv;
  this.io = null;
};

var gdbEmbed;

/**
 * Prefix for text from the pipe mount.
 *
 * @private
 */
Gdb.prefix_ = 'gdb:';

/**
 * Static initialier called from gdb.html.
 *
 * This constructs a new Terminal instance and instructs it to run the Gdb
 * command.
 */
Gdb.init = function() {
  var profileName = lib.f.parseQuery(document.location.search)['profile'];
  var terminal = new hterm.Terminal(profileName);
  terminal.decorate(document.querySelector('#terminal'));

  // Useful for console debugging.
  window.term_ = terminal;

  // We don't properly support the hterm bell sound, so we need to disable it.
  terminal.prefs_.definePreference('audible-bell-sound', '');

  terminal.setAutoCarriageReturn(true);
  terminal.setCursorPosition(0, 0);
  terminal.setCursorVisible(true);
  terminal.runCommandClass(Gdb, document.location.hash.substr(1));

  return true;
};

/**
 * Handle messages sent to us from NaCl.
 *
 * @private
 */
Gdb.prototype.handleMessage_ = function(e) {
  if (e.data.indexOf(Gdb.prefix_) != 0) return;
  var msg = e.data.substring(Gdb.prefix_.length);
  term_.io.print(msg);
}

/**
 * Handle load end event from NaCl.
 */
Gdb.prototype.handleLoadEnd_ = function(e) {
  if (typeof(this.lastUrl) != 'undefined')
    term_.io.print("\n");
  term_.io.print("Loaded.\n");
}

/**
 * Handle load progress event from NaCl.
 */
Gdb.prototype.handleProgress_ = function(e) {
  var url = e.url.substring(e.url.lastIndexOf('/') + 1);
  if (this.lastUrl != url) {
    if (url != '') {
      if (this.lastUrl)
        term_.io.print("\n");
      term_.io.print("Loading " + url + " .");
    }
  } else {
    term_.io.print(".");
  }
  if (url)
  this.lastUrl = url;
}

/**
 * Handle crash event from NaCl.
 */
Gdb.prototype.handleCrash_ = function(e) {
 if (embed.exitStatus == -1) {
   term_.io.print("Program crashed (exit status -1)\n")
 } else {
   term_.io.print("Program exited (status=" + embed.exitStatus + ")\n");
 }
}

function got(str) {
  gdbEmbed.postMessage(Gdb.prefix_ + str);
}

/**
 * Start gdb.
 *
 * This is invoked by the terminal as a result of terminal.runCommandClass().
 */
Gdb.prototype.run = function() {
  this.io = this.argv_.io.push();

  // Create the object for Gdb.
  gdbEmbed = document.createElement('object');
  gdbEmbed.width = 0;
  gdbEmbed.height = 0;
  gdbEmbed.addEventListener('message', this.handleMessage_.bind(this));
  gdbEmbed.addEventListener('progress', this.handleProgress_.bind(this));
  gdbEmbed.addEventListener('loadend', this.handleLoadEnd_.bind(this));
  gdbEmbed.addEventListener('crash', this.handleCrash_.bind(this));
  gdbEmbed.data = 'gdb.nmf';
  gdbEmbed.type = 'application/x-nacl';

  var param_tty = document.createElement('param');
  param_tty.name = 'ps_tty_prefix';
  param_tty.value = Gdb.prefix_;
  gdbEmbed.appendChild(param_tty);

  var param_stdin = document.createElement('param');
  param_stdin.name = 'ps_stdin';
  param_stdin.value = '/dev/tty';
  gdbEmbed.appendChild(param_stdin);

  var param_stdout = document.createElement('param');
  param_stdout.name = 'ps_stdout';
  param_stdout.value = '/dev/tty';
  gdbEmbed.appendChild(param_stdout);

  var param_verbosity = document.createElement('param');
  param_verbosity.name = 'ps_verbosity';
  param_verbosity.value = '2';
  gdbEmbed.appendChild(param_verbosity);

  document.body.appendChild(gdbEmbed);

  this.io.onVTKeystroke = got;
};
