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
  function onProcessExit(code) {
    argv.io.pop();
    if (argv.onExit) {
      argv.onExit(code);
    }
  }
  this.io = argv.io.push();
  var print = this.io.print.bind(this.io);

  this.process_manager = new NaClProcessManager(
    print, onProcessExit, this.io.terminal_.screenSize.width);
};

/**
 * Add the appropriate hooks to HTerm to start the session.
 */
NaClTerm.prototype.run = function() {
  this.io.onVTKeystroke =
    this.process_manager.onVTKeystroke.bind(this.process_manager);
  this.io.onTerminalResize =
    this.process_manager.onTerminalResize.bind(this.process_manager);
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
