/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

'use strict';

/**
 * Prints a string to the terminal.
 * @callback printCallback
 * @param {string} message The string to be printed.
 */

/**
 * This function is called when the main process (usually the shell) exits.
 * @callback mainEndCallback
 * @param {number} code The exit code of the process.
 */

/**
 * NaClProcessManager provides a framework for NaCl executables to run within a
 * web-based terminal.
 *
 * @param {printCallback} print A callback that prints to the terminal.
 * @param {mainEndCallback} onEnd A callback called when the main process exits.
 */
function NaClProcessManager(print, onEnd) {
  this.print = print || function() {};
  this.onEnd = onEnd || function() {};

  this.listeners = {};
};

/**
 * The "no hang" flag for waitpid().
 * @type {number}
 */
NaClProcessManager.WNOHANG = 1;

/**
 * Signal when a process cannot be found.
 * @type {number}
 */
NaClProcessManager.ENOENT = 2;

/**
 * Error when a process does not have unwaited-for children.
 * @type {number}
 */
NaClProcessManager.ECHILD= 10;

/*
 * Character code for Control+C in the terminal.
 * @type {number}
 */
NaClProcessManager.CONTROL_C = 3;

/*
 * Exit code when a process has an error.
 * @type {number}
 */
NaClProcessManager.EX_NO_EXEC = 126;

/*
 * Exit code when a process is ended with SIGKILL.
 * @type {number}
 */
NaClProcessManager.EXIT_CODE_KILL = 128 + 9;

/**
 * This environmnent variable should be set to 1 to enable Control+C quitting
 * of processes.
 * @const
 */
NaClProcessManager.ENV_ABORT = 'ENABLE_CONTROL_C';

/**
 * This is the value to which the ENV_ABORT environment variable should be set
 * in order to enable Control+C.
 * @const
 */
NaClProcessManager.ENV_ABORT_VALUE = '1';


/**
 * Environment variable that can be set to the value in ENV_SPAWN_MODE or
 * ENV_SPAWN_EMBED_VALUE to enable viewing of graphical output from programs.
 * @const
 */
NaClProcessManager.ENV_SPAWN_MODE = 'NACL_SPAWN_MODE';

/**
 * Value for ENV_SPAWN_MODE that makes programs open in a new window.
 * @const
 */
NaClProcessManager.ENV_SPAWN_POPUP_VALUE = 'popup';

/**
 * Value for ENV_SPAWN_MODE that makes the graphical output of programs appear
 * within the terminal window.
 * @const
 */
NaClProcessManager.ENV_SPAWN_EMBED_VALUE = 'embed';

/**
 * Environment variable that can be set to change the width of the popup when
 * ENV_SPAWN_MODE is set to ENV_SPAWN_POPUP_VALUE.
 * @const
 */
NaClProcessManager.ENV_POPUP_WIDTH = 'NACL_POPUP_WIDTH';

/**
 * Environment variable that can be set to change the height of the popup when
 * ENV_SPAWN_MODE is set to ENV_SPAWN_POPUP_VALUE.
 * @const
 */
NaClProcessManager.ENV_POPUP_HEIGHT = 'NACL_POPUP_HEIGHT';

/*
 * Default width for a popup, in pixels.
 * @type {number}
 */
NaClProcessManager.POPUP_WIDTH_DEFAULT = 600;

/*
 * Default height for a popup, in pixels.
 * @type {number}
 */
NaClProcessManager.POPUP_HEIGHT_DEFAULT  = 400;

/**
 * Environment variable that can be set to change the width of the embedded
 * element when ENV_SPAWN_MODE is set to ENV_SPAWN_EMBED_VALUE.
 * @const
 */
NaClProcessManager.ENV_EMBED_WIDTH = 'NACL_EMBED_WIDTH';

/**
 * Environment variable that can be set to change the height of the embedded
 * element when ENV_SPAWN_MODE is set to ENV_SPAWN_EMBED_VALUE.
 * @const
 */
NaClProcessManager.ENV_EMBED_HEIGHT = 'NACL_EMBED_HEIGHT';

/*
 * Default width for a spawned embed, in any units recognized by CSS.
 * @const
 */
NaClProcessManager.EMBED_WIDTH_DEFAULT = '100%';

/*
 * Default height for a spawned embed, in any units recognized by CSS.
 * @const
 */
NaClProcessManager.EMBED_HEIGHT_DEFAULT  = '50%';

// TODO(bradnelson): Rename in line with style guide once we have tests.
// The process which gets the input from the user.
var foreground_process;
// Process information keyed by PID. The value is an embed DOM object
// if the process is running. Once the process has finished, the value
// will be the exit code.
var processes = {};

// Waiter processes keyed by the PID of the waited process. The waiter
// is represented by a hash like
// { element: embed DOM object, wait_req_id: the request ID string }
var waiters = {};
var pid = 0;

/**
 * Handles a NaCl event.
 * @callback eventCallback
 * @param {object} e An object that contains information about the event.
 */

/**
 * Listen for events emitted from the spawned processes.
 * @param {string} evt The event to be waited for.
 * @param {eventCallback} callback The callback to be called on the event.
 */
NaClProcessManager.prototype.addEventListener = function(evt, callback) {
  if (!this.listeners[evt]) {
    this.listeners[evt] = [];
  }
  this.listeners[evt].push(callback);
}

/**
 * Is the given process the root process of this process manager? A root
 * process is the one created by NaClProcessManager and not spawned by
 * another process.
 * @param {HTMLObjectElement} process The element about which one is inquiring.
 */
NaClProcessManager.prototype.isRootProcess = function(process) {
  return !process.parent;
}

/**
 * Makes the path in a NMF entry to fully specified path.
 * @private
 */
NaClProcessManager.prototype.adjustNmfEntry_ = function(entry) {
  for (var arch in entry) {
    var path = entry[arch]['url'];
    // TODO(bradnelson): Generalize this.
    var html5_mount_point = '/mnt/html5/';
    var home_mount_point = '/home/user/';
    var tmp_mount_point = '/tmp/';
    if (path.indexOf(html5_mount_point) == 0) {
      path = path.replace(html5_mount_point,
                          'filesystem:' + location.origin + '/persistent/');
    } else if (path.indexOf(home_mount_point) == 0) {
      path = path.replace(home_mount_point,
                          'filesystem:' + location.origin +
                          '/persistent/home/');
    } else if (path.indexOf(tmp_mount_point) == 0) {
      path = path.replace(tmp_mount_point,
                          'filesystem:' + location.origin +
                          '/temporary/');
    } else {
      // This is for the dynamic loader.
      var base = location.href.match('.*/')[0];
      path = base + path;
    }
    entry[arch]['url'] = path;
  }
}

/**
 * Handle messages sent to us from NaCl.
 * @private
 */
NaClProcessManager.prototype.handleMessage_ = function(e) {
  if (e.data['command'] == 'nacl_spawn') {
    var msg = e.data;
    console.log('nacl_spawn: ' + JSON.stringify(msg));
    var args = msg['args'];
    var envs = msg['envs'];
    var cwd = msg['cwd'];
    var executable = args[0];
    var nmf = msg['nmf'];
    if (nmf) {
      if (nmf['files']) {
        for (var key in nmf['files'])
          this.adjustNmfEntry_(nmf['files'][key]);
      }
      this.adjustNmfEntry_(nmf['program']);
      var blob = new Blob([JSON.stringify(nmf)], {type: 'text/plain'});
      nmf = window.URL.createObjectURL(blob);
    } else {
      if (NaClProcessManager.nmfWhitelist !== undefined &&
          NaClProcessManager.nmfWhitelist.indexOf(executable) === -1) {
        var reply = {};
        reply[e.data['id']] = {
          pid: -NaClProcessManager.ENOENT,
        };
        console.log('nacl_spawn(error): ' + JSON.stringify(reply));
        e.srcElement.postMessage(reply);
        return;
      }
      nmf = executable + '.nmf';
    }
    var pid = this.spawn(nmf, args, envs, cwd, executable, e.srcElement);
    var reply = {};
    reply[e.data['id']] = {
      pid: pid
    };
    e.srcElement.postMessage(reply);
  } else if (e.data['command'] == 'nacl_wait') {
    var msg = e.data;
    console.log('nacl_wait: ' + JSON.stringify(msg));
    this.waitpid(msg['pid'], msg['options'], function(pid, status) {
      var reply = {};
      reply[msg['id']] = {
        pid: pid,
        status: status
      };
      e.srcElement.postMessage(reply);
    });
  } else if (e.data.indexOf('exited') == 0) {
    var exitCode = parseInt(e.data.split(':', 2)[1]);
    if (isNaN(exitCode))
      exitCode = 0;
    this.exit(exitCode, e.srcElement);
  }
}

/**
 * Handle abort event from NaCl.
 * @private
 */
NaClProcessManager.prototype.handleLoadAbort_ = function(e) {
  this.exit(NaClProcessManager.EXIT_CODE_KILL, e.srcElement);
}

/**
 * Handle load error event from NaCl.
 * @private
 */
NaClProcessManager.prototype.handleLoadError_ = function(e) {
  this.exit(NaClProcessManager.EX_NO_EXEC, e.srcElement);
}

/**
 * Handle crash event from NaCl.
 * @private
 */
NaClProcessManager.prototype.handleCrash_ = function(e) {
  this.exit(e.srcElement.exitStatus, e.srcElement);
}

/**
 * Exit the command.
 * @param {number} code The exit code of the process.
 * @param {HTMLObjectElement} element The HTML element of the exited process.
 */
NaClProcessManager.prototype.exit = function(code, element) {
  if (!element.parent) {
    this.onEnd(code, element);
    return;
  }

  var pid = element.pid;
  function wakeWaiters(waiters) {
    for (var i = 0; i < waiters.length; i++) {
      var waiter = waiters[i];
      waiter.reply(pid, code);
      waiter = null;
    }
  }
  if (waiters[pid] || waiters[-1]) {
    if (waiters[pid]) {
      wakeWaiters(waiters[pid]);
      delete waiters[pid];
    }
    if (waiters[-1]) {
      wakeWaiters(waiters[-1]);
      delete waiters[-1];
    }

    delete processes[pid];
  } else {
    processes[pid] = code;
  }

  // Mark as terminated.
  element.pid = -1;
  var next_foreground_process = null;
  if (foreground_process == element) {
    next_foreground_process = element.parent;
    // When the parent has already finished, give the control to the
    // grand parent.
    while (next_foreground_process.pid == -1)
      next_foreground_process = next_foreground_process.parent;
  }

  // Clean up HTML elements.
  if (element.parentNode == document.body) {
    document.body.removeChild(element);
  }

  if (element.popup) {
    element.popup.destroy();
  }

  if (next_foreground_process)
    foreground_process = next_foreground_process;

  return;
};

/**
 * This spawns a new NaCl process in the current window by creating an HTML
 * embed element.
 *
 * When creating the initial process, we delay this until the first terminal
 * resize event so that we start with the correct size.
 *
 * @param {string} nmf The path to the NaCl NMF file.
 * @param {Array.<string>} argv The command-line arguments to be given to the
 *     spawned process.
 * @param {Array.<string>} envs The environment variables that the spawned
 *     process can access. Each entry in the array should be of the format
 *     "VARIABLE_NAME=value".
 * @param {string} cwd The current working directory.
 * @param {string} command_name The name of the process to be spawned.
 * @param {HTMLObjectElement} [parent=null] The DOM object that corresponds to
 *     the process that initiated the spawn. Set to null if there is no such
 *     process.
 * @returns {number} PID of the spawned process, or -1 if there was an error.
 */
NaClProcessManager.prototype.spawn = function(nmf, argv, envs, cwd,
                                    command_name, parent) {
  if (!parent) parent = null;

  var mimetype = 'application/x-nacl';
  if (navigator.mimeTypes[mimetype] === undefined) {
    if (mimetype.indexOf('pnacl') != -1)
      this.print('Browser does not support PNaCl or PNaCl is disabled\n');
    else
      this.print('Browser does not support NaCl or NaCl is disabled\n');
    return -1;
  }

  ++pid;
  foreground_process = document.createElement('object');
  foreground_process.pid = pid;
  foreground_process.width = 0;
  foreground_process.height = 0;
  foreground_process.data = nmf;
  foreground_process.type = mimetype;
  foreground_process.parent = parent;
  foreground_process.command_name = command_name;

  for (var evt in this.listeners) {
    if (this.listeners.hasOwnProperty(evt)) {
      for (var i = 0; i < this.listeners[evt].length; i++) {
        foreground_process.addEventListener(evt, this.listeners[evt][i]);
      }
    }
  }
  foreground_process.addEventListener(
      'abort', this.handleLoadAbort_.bind(this));
  foreground_process.addEventListener(
      'message', this.handleMessage_.bind(this));
  foreground_process.addEventListener(
      'error', this.handleLoadError_.bind(this));
  foreground_process.addEventListener('crash', this.handleCrash_.bind(this));

  processes[pid] = foreground_process;

  var params = {};
  for (var i = 0; i < envs.length; i++) {
    var env = envs[i];
    var index = env.indexOf('=');
    if (index < 0) {
      console.error('Broken env: ' + env);
      continue;
    }
    var key = env.substring(0, index);
    if (key == 'SRC' || key == 'DATA' || key.match(/^ARG\d+$/i))
      continue;
    params[key] = env.substring(index + 1);
  }

  params['PS_TTY_PREFIX'] = NaClProcessManager.prefix;
  params['PS_TTY_RESIZE'] = 'tty_resize';
  params['PS_TTY_COLS'] = this.tty_width;
  params['PS_TTY_ROWS'] = this.tty_height;
  params['PS_STDIN'] = '/dev/tty';
  params['PS_STDOUT'] = '/dev/tty';
  params['PS_STDERR'] = '/dev/tty';
  params['PS_VERBOSITY'] = '2';
  params['PS_EXIT_MESSAGE'] = 'exited';
  params['TERM'] = 'xterm-256color';
  params['PWD'] = cwd;
  // TODO(bradnelson): Drop this hack once tar extraction first checks relative
  // to the nexe.
  if (NaClProcessManager.useNaClAltHttp === true) {
    params['NACL_ALT_HTTP'] = '1';
  }

  function addParam(name, value) {
    var param = document.createElement('param');
    param.name = name;
    param.value = value;
    foreground_process.appendChild(param);
  }

  for (var key in params) {
    addParam(key, params[key]);
  }

  // Add ARGV arguments from query parameters.
  function parseQuery(query) {
    if (query.charAt(0) === '?') {
      query = query.substring(1);
    }
    var splitArgs = query.split('&');
    var args = {};
    for (var i = 0; i < splitArgs.length; i++) {
      var keyValue = splitArgs[i].split('=');
      args[decodeURIComponent(keyValue[0])] = decodeURIComponent(keyValue[1]);
    }
    return args;
  }
  var args = parseQuery(document.location.search);
  for (var argname in args) {
    addParam(argname, args[argname]);
  }

  // If the application has set NaClProcessManager.argv and there were
  // no arguments set in the query parameters then add the default
  // NaClProcessManager.argv arguments.
  // TODO(bradnelson): Consider dropping this method of passing in parameters.
  if (args['arg1'] === undefined && argv) {
    var argn = 0;
    argv.forEach(function(arg) {
      var argname = 'arg' + argn;
      addParam(argname, arg);
      argn = argn + 1
    })
  }

  // We show this message only for the first process.
  if (pid == 1)
    this.print('Loading NaCl module.\n');

  if (params[NaClProcessManager.ENV_SPAWN_MODE] ===
      NaClProcessManager.ENV_SPAWN_POPUP_VALUE) {
    var self = this;
    var popup = new GraphicalPopup(
      foreground_process,
      parseInt(params[NaClProcessManager.ENV_POPUP_WIDTH] ||
               NaClProcessManager.POPUP_WIDTH_DEFAULT),
      parseInt(params[NaClProcessManager.ENV_POPUP_HEIGHT] ||
               NaClProcessManager.POPUP_HEIGHT_DEFAULT),
      argv[0]
    );
    popup.setClosedListener(function() {
      self.exit(NaClProcessManager.EXIT_CODE_KILL, popup.process);
      GraphicalPopup.focusCurrentWindow();
    });

    foreground_process.popup = popup;

    popup.create();
  } else {
    if (params[NaClProcessManager.ENV_SPAWN_MODE] ===
               NaClProcessManager.ENV_SPAWN_EMBED_VALUE) {
      var style = foreground_process.style;
      style.position = 'absolute';
      style.top = 0;
      style.left = 0;
      style.width = params[NaClProcessManager.ENV_EMBED_WIDTH] ||
        NaClProcessManager.EMBED_WIDTH_DEFAULT;
      style.height = params[NaClProcessManager.ENV_EMBED_HEIGHT] ||
        NaClProcessManager.EMBED_HEIGHT_DEFAULT;
    }
    document.body.appendChild(foreground_process);
  }
  return pid;
}

/**
 * Handles the exiting of a process.
 * @callback waitCallback
 * @param {number} pid The PID of the process that exited or an error code on
 *     error.
 * @param {number} status The exit code of the process.
 */

/**
 * Waits for the process identified by pid to exit, and call a callback when
 * finished.
 * @param {number} pid The process ID of the process.
 * @param {number} options The desired options, ORed together.
 * @param {waitCallback} reply The callback to be called when the process has
 *     exited.
 */
NaClProcessManager.prototype.waitpid = function(pid, options, reply) {
  var finishedProcess = null;
  Object.keys(processes).some(function(pid) {
    if (typeof processes[pid] == 'number') {
      finishedProcess = pid;
      return true;
    }
    return false;
  });

  if (pid == -1 && finishedProcess !== null) {
    reply(parseInt(finishedProcess), processes[finishedProcess]);
    delete processes[finishedProcess];
  } else if (pid >= 0 && !processes[pid]) {
    // The process does not exist.
    reply(-NaClProcessManager.ECHILD, 0);
  } else if (typeof processes[pid] == 'number') {
    // The process has already finished.
    reply(pid, processes[pid]);
    delete processes[pid];
  } else {
    // Add the current process to the waiter list.
    if (options & this.WNOHANG != 0) {
      reply(0, 0);
      return;
    }
    if (!waiters[pid]) {
      waiters[pid] = [];
    }
    waiters[pid].push({
      reply: reply,
      options: options
    });
  }
}

NaClProcessManager.prototype.onTerminalResize = function(width, height) {
  this.tty_width = width;
  this.tty_height = height;
  if (foreground_process === undefined) {
    var argv = NaClProcessManager.argv || [];
    argv = [NaClProcessManager.nmf].concat(argv);
    this.spawn(NaClProcessManager.nmf, argv, [], '/',
               NaClProcessManager.prefix);
  } else {
    foreground_process.postMessage({'tty_resize': [ width, height ]});
  }
}

NaClProcessManager.prototype.onVTKeystroke = function(str) {
  // TODO(bradnelson): Change this once we support signals.
  // Abort on Control+C, but don't quit bash.
  if (str.charCodeAt(0) === NaClProcessManager.CONTROL_C &&
      foreground_process.parent !== null) {
    // Only exit if the appropriate environment variable is set.
    var query = 'param[name="' + NaClProcessManager.ENV_ABORT + '"]';
    var enabledEnv = foreground_process.querySelector(query);
    if (enabledEnv && enabledEnv.value === NaClProcessManager.ENV_ABORT_VALUE) {
      this.exit(NaClProcessManager.EXIT_CODE_KILL, foreground_process);
      this.print('\n');
    }
  } else {
    var message = {};
    message[NaClProcessManager.prefix] = str;
    foreground_process.postMessage(message);
  }
}

/**
 * This creates a popup that runs a NaCl process inside.
 *
 * @param {Object} process The NaCl process to be run.
 * @param {number} width
 * @param {number} height
 * @param {string} title
 */
function GraphicalPopup(process, width, height, title) {
  this.process = process || null;
  this.width = width || GraphicalPopup.DEFAULT_WIDTH;
  this.height = height || GraphicalPopup.DEFAULT_HEIGHT;
  this.title = title || '';
  this.win = null;
  this.onClosed = function () {};
}

/**
 * The default width of the popup.
 * @type {number}
 */
GraphicalPopup.DEFAULT_WIDTH = 600;

/**
 * The default height of the popup.
 * @type {number}
 */
GraphicalPopup.DEFAULT_HEIGHT = 400;

/**
 * The (empty) HTML file to which the NaCl module is added.
 * @const
 */
GraphicalPopup.HTML_FILE = 'graphical.html';

/**
 * Focus the window in which this code is run.
 */
GraphicalPopup.focusCurrentWindow = function() {
  chrome.app.window.current().focus();
}

/**
 * This callback is called when the popup is closed.
 * @callback closedCallback
 */

/**
 * Set a function to be called as a callback when the popup is closed.
 * @param {closedCallback} listener
 */
GraphicalPopup.prototype.setClosedListener = function(listener) {
  if (this.win) {
    throw new Error("Cannot set closed listener after creating window.");
  }
  this.onClosed = listener;
}

/**
 * Create the window.
 */
GraphicalPopup.prototype.create = function() {
  var self =  this;
  chrome.app.window.create('graphical.html', {
    'bounds': {
      'width': self.width,
      'height': self.height
    },
  }, function(win) {
    var process = self.process;
    var popup = win.contentWindow;

    self.win = process.window = win;

    popup.document.title = self.title;

    popup.addEventListener('load', function() {
      process.style.position = 'absolute';
      process.style.top = '0';
      process.style.left = '0';
      process.style.width = '100%';
      process.style.height = '100%';
      popup.document.body.appendChild(process);
    });

    popup.focused = true;
    popup.addEventListener('focus', function() {
      this.focused = true;
    });
    popup.addEventListener('blur', function() {
      this.focused = false;
    });

    win.onClosed.addListener(self.onClosed);
  });
}

/**
 * Close the popup.
 */
GraphicalPopup.prototype.destroy = function() {
  if (this.win.contentWindow.focused) {
    GraphicalPopup.focusCurrentWindow();
  }
  this.win.onClosed.removeListener(this.onClosed);
  this.win.close();

  this.process = null;
  this.win = null;
}
