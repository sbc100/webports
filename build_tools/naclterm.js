/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

'use strict';

lib.rtdep('lib.f',
          'hterm',
          'NaClProcessManager');

// CSP means that we can't kick off the initialization from the html file,
// so we do it like this instead.
window.onload = function() {
  lib.init(function() {
    NaClTerm.init();
  });
};

/**
 * This class uses the NaClProcessManager to run NaCl executables within an
 * hterm.
 *
 * @param {Object} argv The argument object passed in from the Terminal.
 */
function NaClTerm(argv) {
  // TODO(channingh):  Get rid of this workaround once we have migrated all
  // functions that require prefix in NaClProcessManager.
  NaClTerm.prefix = NaClProcessManager.prefix;

  this.argv = argv;
  this.io = argv.io.push();
  this.width = this.io.terminal_.screenSize.width;

  this.bufferedOutput = '';

  // Have we started spawning the initial process?
  this.started = false;

  // Has the initial process finished loading?
  this.loaded = false;

  this.print = this.io.print.bind(this.io);

  var mgr = this.process_manager = new NaClProcessManager(
      this.print, this.handleExit_.bind(this));

  mgr.addEventListener('abort', this.handleLoadAbort_.bind(this));
  mgr.addEventListener('error', this.handleLoadError_.bind(this));
  mgr.addEventListener('load', this.handleLoad_.bind(this));
  mgr.addEventListener('message', this.handleMessage_.bind(this));
  mgr.addEventListener('progress', this.handleProgress_.bind(this));
};

/**
 * Flag for cyan coloring in the terminal.
 * @const
 */
NaClTerm.ANSI_CYAN = '\x1b[36m';

/**
 * Flag for color reset in the terminal.
 * @const
 */
NaClTerm.ANSI_RESET = '\x1b[0m';

/**
 * Add the appropriate hooks to HTerm to start the session.
 */
NaClTerm.prototype.run = function() {
  this.io.onVTKeystroke =
    this.process_manager.onVTKeystroke.bind(this.process_manager);
  this.io.onTerminalResize = this.onTerminalResize_.bind(this);

  this.print(NaClTerm.ANSI_CYAN);
}

/**
 * Static initializer called from index.html.
 *
 * This constructs a new Terminal instance and instructs it to run a NaClTerm.
 */
NaClTerm.init = function() {
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
  terminal.runCommandClass(NaClTerm, document.location.hash.substr(1));

  return true;
};

/**
 * Handle message event from NaCl.
 * @private
 * @param {object} e An object that contains information about the event.
 */
NaClTerm.prototype.handleMessage_ = function(e) {
  if (typeof e.data === 'string' && e.data.indexOf(NaClTerm.prefix) === 0) {
    var msg = e.data.substring(NaClTerm.prefix.length);
    if (!this.loaded) {
      this.bufferedOutput += msg;
    } else {
      this.print(msg);
    }
  }
}

/**
 * Handle load abort event from NaCl.
 * @private
 * @param {object} e An object that contains information about the event.
 */
NaClTerm.prototype.handleLoadAbort_ = function(e) {
  this.print('Load aborted.\n');
}

/**
 * Handle load error event from NaCl.
 * @private
 * @param {object} e An object that contains information about the event.
 */
NaClTerm.prototype.handleLoadError_ = function(e) {
  this.print(e.srcElement.command_name + ': ' +
             e.srcElement.lastError + '\n');
}

/**
 * Notify the user when we are done loading a URL.
 * @private
 */
NaClTerm.prototype.doneLoadingUrl_ = function() {
  var width = this.width;
  this.print('\r' + Array(width+1).join(' '));
  var message = '\rLoaded ' + this.lastUrl;
  if (this.lastTotal) {
    var kbsize = Math.round(this.lastTotal/1024)
    message += ' ['+ kbsize + ' KiB]';
  }
  this.print(message.slice(0, width) + '\n')
}

/**
 * Handle load end event from NaCl.
 * @private
 * @param {object} e An object that contains information about the event.
 */
NaClTerm.prototype.handleLoad_ = function(e) {
  // Don't print loading messages, except for the
  // root process.
  if (this.process_manager.isRootProcess(e.srcElement)) {
    if (this.lastUrl)
      this.doneLoadingUrl_();
    else
      this.print('Loaded.\n');

    this.print(NaClTerm.ANSI_RESET);
  }

  // Now that have completed loading and displaying
  // loading messages we output any messages from the
  // NaCl module that were buffered up unto this point
  this.loaded = true;
  this.print(this.bufferedOutput);
  this.bufferedOutput = '';
}

/**
 * Handle load progress event from NaCl.
 * @private
 * @param {object} e An object that contains information about the event.
 */
NaClTerm.prototype.handleProgress_ = function(e) {
  if (e.url !== undefined)
    var url = e.url.substring(e.url.lastIndexOf('/') + 1);

  if (!e.srcElement.parent && this.lastUrl && this.lastUrl != url)
    this.doneLoadingUrl_()

  if (!url)
    return;

  this.lastUrl = url;
  this.lastTotal = e.total;

  if (!this.process_manager.isRootProcess(e.srcElement))
    return;

  var message = 'Loading ' + url;
  if (e.lengthComputable && e.total) {
    var percent = Math.round(e.loaded * 100 / e.total);
    var kbloaded = Math.round(e.loaded / 1024);
    var kbtotal = Math.round(e.total / 1024);
    message += ' [' + kbloaded + ' KiB/' + kbtotal + ' KiB ' + percent + '%]';
  }

  this.print('\r' + message.slice(-this.width));
}

/**
 * Clean up once a process exits.
 * @private
 * @param {number} code The exit code of the process.
 * @param {HTMLObjectElement} element The HTML element of the exited process.
 */
NaClTerm.prototype.handleExit_ = function(code, element) {
  this.print(NaClTerm.ANSI_CYAN)

  // The root process finished.
  if (code === -1) {
    this.print('Program (' + element.command_name +
                         ') crashed (exit status -1)\n');
  } else {
    this.print('Program (' + element.command_name + ') exited ' +
               '(status=' + code + ')\n');
  }
  this.argv.io.pop();
  if (this.argv.onExit) {
    this.argv.onExit(code);
  }
}

/**
 * Handle hterm terminal resize events.
 * @private
 * @param {number} width The width of the terminal.
 * @param {number} height The height of the terminal.
 */
NaClTerm.prototype.onTerminalResize_ = function(width, height) {
  this.process_manager.onTerminalResize(width, height);
  if (this.started) {
    return;
  }
  var argv = NaClTerm.argv || [];
  argv = [NaClTerm.nmf].concat(argv);
  this.process_manager.spawn(NaClTerm.nmf, argv, [], '/');
  this.started = true;
}
