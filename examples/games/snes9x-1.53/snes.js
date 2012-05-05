/*
  Copyright (c) 2012 The Native Client Authors. All rights reserved.
  Use of this source code is governed by a BSD-style license that can be
  found in the LICENSE file.
*/

var snesModule = null;
var game_id_;
var save = '';
var key_state = {};

window.BlobBuilder = window.BlobBuilder ||
    window.WebKitBlobBuilder || window.MozBlobBuilder;
window.URL = window.URL || window.webkitURL;
window.requestFileSystem = window.requestFileSystem ||
    window.webkitRequestFileSystem;

var store;

function Storage() {

  this.fs_ = null;

  this.errorHandler = function(err) {
    var msg = 'An error occured: ';

    switch (err.code) {
      case FileError.NOT_FOUND_ERR:
        msg += 'File or directory not found';
        break;

      case FileError.NOT_READABLE_ERR:
        msg += 'File or directory not readable';
        break;

      case FileError.PATH_EXISTS_ERR:
        msg += 'File or directory already exists';
        break;

      case FileError.TYPE_MISMATCH_ERR:
        msg += 'Invalid filetype';
        break;

      default:
        msg += 'Unknown Error, error code: ' + err.code;
        break;
    };

    console.log(msg);
  };
}

Storage.prototype.init = function() {
  var self = this;
  window.requestFileSystem(window.PERSISTENT, 100 * 1024 * 1024,
    function(filesystem) {
      self.fs_ = filesystem;
      console.log("fs success!");
    },
    self.errorHandler);
};

// XXX: needs to run manually now.
Storage.prototype.requestQuota = function() {
  window.webkitStorageInfo.requestQuota(PERSISTENT, 100*1024*1024,
    function(grantedBytes) {
      alert('yay!');
    }, function(e) {
      alert('no way!');
    });
};

Storage.prototype.saveName = function(game, index) {
  return game + '-' + index;
};

Storage.prototype.save = function(game, index, blob) {
  this.replace(this.saveName(game, index), blob);
};

Storage.prototype.replace = function(filename, blob) {
  var self = this;
  var root = this.fs_.root;
  root.getFile(filename, {create: true}, function(fileEntry) {
    fileEntry.createWriter(function(fileWriter) {
      fileWriter.onwriteend = function(e) {
        console.log('Write completed.');
      };
      fileWriter.onerror = function(e) {
        console.log('Write failed: ' + e.toString());
      };

      fileWriter.write(blob);
    }, self.errorHandler);
  }, self.errorHandler);
};

Storage.prototype.load = function(game, index, callback) {
  var self = this;
  var root = this.fs_.root;
  var filename = this.saveName(game, index);
  root.getFile(filename, {}, function(fileEntry) {
    fileEntry.file(function(file) {
      buildArrayBuffer(callback, index, file);
    }, self.errorHandler);
  }, self.errorHandler);
};

Storage.prototype.list = function(game, callback) {
  var root = this.fs_.root;
  root.createReader().readEntries(function(entries) {
    for(var i = 0; i < entries.length; i++) {
      var entry = entries[i];
      if (entry.isDirectory) {
        console.log('Directory: ' + entry.fullPath);
      } else if (entry.isFile) {
        console.log('File: ' + entry.fullPath);
        if (entry.name.indexOf(game) >= 0) {
          callback(entry);
        }
      }
    }
  });
};

Storage.prototype.remove = function(filename) {
  var self = this;
  this.fs_.root.getFile(filename, {create: false}, function(fileEntry) {
    fileEntry.remove(function() {
      console.log('File removed.');
    }, self.errorHandler);
  }, self.errorHandler)
};

// Indicate success when the NaCl module has loaded.
function moduleDidLoad() {
  snesModule = document.getElementById('snes');
}

function arrayBufferToString(buffer, callback) {
  var blobBuilder = new BlobBuilder();
  blobBuilder.append(buffer);

  var fileReader = new FileReader();
  fileReader.onload = function(e) {
    callback(e.target.result);
  };
  fileReader.readAsBinaryString(blobBuilder.getBlob());
}

function buildArrayBuffer(callback) {
  var blobBuilder = new BlobBuilder();
  for (var i = 1; i < arguments.length; ++i) {
    blobBuilder.append(arguments[i]);
  }

  var fileReader = new FileReader();
  fileReader.onload = function(e) {
    callback(e.target.result);
  };
  fileReader.readAsArrayBuffer(blobBuilder.getBlob());
}

// Handle a message coming from the NaCl module.
function handleMessage(message_event) {
  console.log('Received message');
  if (typeof message_event.data == 'string') {
    if (message_event.data.indexOf('ACK_SAVE_') == 0) {
      var index = message_event.data[9];
      downloadSave(index);
    }
    return;
  }

  var bb = new BlobBuilder();
  bb.append(message_event.data);
  var blob = bb.getBlob();
  arrayBufferToString(blob.webkitSlice(0, 1), function(index) {
    store.save(game_id_, index, blob.webkitSlice(1));
  });
}

function uploadSave(index, callback) {
  store.load(game_id_, index, function(buffer) {
    snesModule.postMessage(buffer);
    callback();
  });
}

function downloadSave(index) {
    console.log('downloadSave ' + index);
  document.getElementById('snes').postMessage('S ' + index);
}

function stringToBlob(str) {
  var blobBuilder = new BlobBuilder()
  blobBuilder.append(str);
  return blobBuilder.getBlob();
}


function createGameSaveNode(key, url) {
  var save = document.createElement('div');
  save.setAttribute('draggable', true);
  save.setAttribute('class', 'save');
  save.setAttribute('data-downloadurl',
      'application/octet-stream:' + key + '.sav:' +
      url);

  save.appendChild(document.createTextNode(key));

  save.addEventListener("dragstart", function(evt) {
    evt.dataTransfer.setData('DownloadURL', this.dataset.downloadurl);
  }, false);

  save.addEventListener("dragover", function(evt) {
    evt.stopPropagation();
    evt.preventDefault();
    evt.dataTransfer.dropEffect = 'copy';  // Explicitly show this is a copy.
  }, false);

  save.addEventListener("drop", function(evt) {
    evt.stopPropagation();
    evt.preventDefault();

    var file = evt.dataTransfer.files[0];
    store.replace(key, file);
    console.log('save to ' + key);
  }, false);

  return save;
}

function initDirectory() {
  var dir = document.getElementById('directory');
  store.list(game_id_, function(entry) {
    var entry = createGameSaveNode(entry.name,
        entry.toURL('application/octet-stream'));
    dir.appendChild(entry);
  });
}

function onload() {
  var listener = document.getElementById('listener')
  listener.addEventListener('load', moduleDidLoad, true);
  listener.addEventListener('message', handleMessage, true);

  document.getElementById('romfile').addEventListener(
      'change', handleFileSelect, false);

  store = new Storage();
  store.init();
}

var keyMap = {
  // System
  '192': 'TURBO',

  // Save/Load
  'S+1': 'SAVE_1',
  'S+2': 'SAVE_2',
  'S+3': 'SAVE_3',
  'S+4': 'SAVE_4',
  'S+5': 'SAVE_5',
  'S+6': 'SAVE_6',
  'S+7': 'SAVE_7',
  'S+8': 'SAVE_8',
  'S+9': 'SAVE_9',
  '1': 'LOAD_1',
  '2': 'LOAD_2',
  '3': 'LOAD_3',
  '4': 'LOAD_4',
  '5': 'LOAD_5',
  '6': 'LOAD_6',
  '7': 'LOAD_7',
  '8': 'LOAD_8',
  '9': 'LOAD_9',

  // Joypad 1
  '38': 'J1_UP',
  '40': 'J1_DOWN',
  '37': 'J1_LEFT',
  '39': 'J1_RIGHT',
  '13': 'J1_START',
  '9': 'J1_SELECT',

  'Z': 'J1_A',
  'X': 'J1_B',
  'A': 'J1_X',
  'S': 'J1_Y',
  'Q': 'J1_L',
  'W': 'J1_R',

  // Joypad 2
  'K': 'J2_UP',
  '188': 'J2_DOWN',
  'M': 'J2_LEFT',
  '190': 'J2_RIGHT',
  '187': 'J2_START',
  '189': 'J2_SELECT',

  'V': 'J2_A',
  'B': 'J2_B',
  'F': 'J2_X',
  'G': 'J2_Y',
  'R': 'J2_L',
  'T': 'J2_R',
};

var loaded_from_localstore = {};

function post(act, evt) {
  var ch = String.fromCharCode(evt.keyCode);
  if (event.shiftKey) {
    ch = 'S+' + ch;
  }

  if (key_state[ch] == act) {
    return false;
  }
  key_state[ch] = act;

  var cmd = keyMap[ch];
  if (cmd !== undefined) {
    // Intercept LOAD_$N command, so that after boot up, file in localStorage
    // can be uploaded to (ram) disk of the module for SNES to read.  It's hard
    // to know the status of the running SNES, so for now I simply intercept
    // the first loading command.
    if (cmd.indexOf('LOAD_') === 0 && act == 'down') {
      var index = cmd.substring(5);

      // It only needs to be done once. Afterward, file lives in the disk and
      // we don't need to read from localStorage. In case of saving, we write
      // (i.e. write through) to both file on the disk and localStorage.
      if (!loaded_from_localstore[index]) {
        uploadSave(index, function() {
          snesModule.postMessage('K' + act + ';' + cmd);
          loaded_from_localstore[index] = true;
        });
        return;
      }
    }

    snesModule.postMessage('K' + act + ';' + cmd);
  } else if (keyMap[evt.keyCode] !== undefined) {
    snesModule.postMessage('K' + act + ';' + keyMap[evt.keyCode]);
  } else {
    console.log('KEY UNDEFINEDL ' + evt.keyCode + '(' + ch + ')');
  }
  return false;
}

//document.onkeypress = function(evt) { return post('press', evt); };
document.onkeydown = function(evt) { return post('down', evt); };
document.onkeyup = function(evt) { return post('up', evt); };

var sleep_period = 100;

function press(acts) {
  if (typeof acts === 'string') {
    acts = [acts];
  }
  if (acts.length == 0) {
    return;
  }
  var msg = acts.shift();
  snesModule.postMessage('Kdown;' + msg);
  setTimeout(function() {
    snesModule.postMessage('Kup;' + msg);
    press(acts);
  }, sleep_period);
}

function loadFromLocal(file) {
  var rom_url = URL.createObjectURL(file);
  startGame(file.name, rom_url);
}

function startGame(id, url) {
  game_id_ = id;

  var nacl = document.createElement('embed');
  nacl.setAttribute('name', 'nacl_module');
  nacl.setAttribute('id', 'snes');
  nacl.setAttribute('width', 256 * 3);
  nacl.setAttribute('height', 239 * 3);
  nacl.setAttribute('src', 'snes.nmf');
  nacl.setAttribute('type', 'application/x-nacl');
  nacl.setAttribute('filename',  url);

  document.getElementById('game').innerHTML = '';
  document.getElementById('game').appendChild(nacl);

  initDirectory();
}

function handleFileSelect(evt) {
  loadFromLocal(evt.target.files[0]);
}

function resizeView(that) {
  snesModule.postMessage('V' + that.value);
}

function pauseOrResume(button) {
  if (button.firstChild.data == "Pause") {
    button.firstChild.data = "Resume";
  } else {
    button.firstChild.data = "Pause";
  }
  snesModule.postMessage('Kdown;PAUSE');
}
