// Copyright 2011 (c) The Native Client Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/**
 * @file
 * The life Application object.  This object instantiates a Dragger object and
 * connects it to the element named @a life_module.
 */

goog.provide('life.Application');

goog.require('goog.Disposable');
goog.require('goog.events.EventType');
goog.require('goog.style');

goog.require('life.controllers.ViewController');

/**
 * Constructor for the Application class.  Use the run() method to populate
 * the object with controllers and wire up the events.
 * @constructor
 * @extends {goog.Disposable}
 */
life.Application = function() {
  goog.Disposable.call(this);
}
goog.inherits(life.Application, goog.Disposable);

/**
 * The view controller for the application.  A DOM element that encapsulates
 * the grayskull plugin; this is allocated at run time.  Connects to the
 * element with id life.Application.DomIds_.VIEW.
 * @type {life.ViewController}
 * @private
 */
life.Application.prototype.viewController_ = null;

/**
 * The ids used for elements in the DOM.  The Life Application expects these
 * elements to exist.
 * @enum {string}
 * @private
 */
life.Application.DomIds_ = {
  BIRTH_FIELD: 'birth_field',  // Text field with the birth rule string.
  CLEAR_BUTTON: 'clear_button',  // The clear button element.
  KEEP_ALIVE_FIELD: 'keep_alive_field',  // Keep alive rule string.
  MODULE: 'life_module',  // The <embed> element representing the NaCl module.
  PLAY_MODE_SELECT: 'play_mode_select',  // The <select> element for play mode.
  PLAY_BUTTON: 'play_button',  // The play button element.
  VIEW: 'life_view'  // The <div> containing the NaCl element.
};

/**
 * The Run/Stop button attribute labels.  These are used to determine the state
 * and label of the button.
 * @enum {string}
 * @private
 */
life.Application.PlayButtonAttributes_ = {
  ALT_TEXT: 'alttext',  // Text to display in the "on" state.
  STATE: 'state'  // The button's state.
};

/**
 * Place-holder to make the onload event handling process all work.
 */
var loadingLifeApp_ = {};

/**
 * Override of disposeInternal() to dispose of retained objects.
 * @override
 */
life.Application.prototype.disposeInternal = function() {
  this.terminate();
  life.Application.superClass_.disposeInternal.call(this);
}

/**
 * Called by the module loading function once the module has been loaded. Wire
 * up a Dragger object to @a this.
 * @param {!Element} nativeModule The instance of the native module.
 * @param {?String} opt_contentDivId The id of a DOM element which captures
 *     the UI events.  If unspecified, defaults to DEFAULT_DIV_ID.  The DOM
 *     element must exist.
 */
life.Application.prototype.moduleDidLoad =
    function(nativeModule, opt_contentDivId) {
  contentDivId = opt_contentDivId || life.Application.DEFAULT_DIV_ID;
  var contentDiv = document.getElementById(contentDivId);
  // Listen for 'unload' in order to terminate cleanly.
  goog.events.listen(window, goog.events.EventType.UNLOAD, this.terminate);

  // Set up the view controller, it contains the NaCl module.
  this.viewController_ = new life.controllers.ViewController(nativeModule);

  // Wire up the various controls.
  var playModeSelect = goog.dom.$(life.Application.DomIds_.PLAY_MODE_SELECT);
  if (playModeSelect) {
    goog.events.listen(playModeSelect, goog.events.EventType.CHANGE,
        this.selectPlayMode, false, this);
  }

  var clearButton = goog.dom.$(life.Application.DomIds_.CLEAR_BUTTON);
  if (clearButton) {
    goog.events.listen(clearButton, goog.events.EventType.CLICK,
        this.clear, false, this);
  }

  var playButton = goog.dom.$(life.Application.DomIds_.PLAY_BUTTON);
  if (playButton) {
    goog.events.listen(playButton, goog.events.EventType.CLICK,
        this.togglePlayButton, false, this);
  }
}

/**
 * Change the play mode.
 * @param {!goog.events.Event} changeEvent The CHANGE event that triggered this
 *     handler.
 */
life.Application.prototype.selectPlayMode = function(changeEvent) {
  changeEvent.stopPropagation();
  this.viewController_.setPlayMode(changeEvent.target.value);
}

/**
 * Toggle the simulation.
 * @param {!goog.events.Event} clickEvent The CLICK event that triggered this
 *     handler.
 */
life.Application.prototype.togglePlayButton = function(clickEvent) {
  clickEvent.stopPropagation();
  var button = clickEvent.target;
  var buttonText = button.innerText;
  var altText = button.getAttribute(
      life.Application.PlayButtonAttributes_.ALT_TEXT);
  var state = button.getAttribute(
      life.Application.PlayButtonAttributes_.STATE);
  // Switch the inner and alternate labels.
  button.innerText = altText;
  button.setAttribute(life.Application.PlayButtonAttributes_.ALT_TEXT,
                      buttonText);
  if (state == 'off') {
    button.setAttribute(
        life.Application.PlayButtonAttributes_.STATE, 'on');
    this.viewController_.run();
  } else {
    button.setAttribute(
        life.Application.PlayButtonAttributes_.STATE, 'off');
    this.viewController_.stop();
  }
}

/**
 * Clear the current simulation.
 * @param {!goog.events.Event} clickEvent The CLICK event that triggered this
 */
life.Application.prototype.clear = function(clickEvent) {
  clickEvent.stopPropagation();
  this.viewController_.clear();
}

/**
 * Asserts that cond is true; issues an alert and throws an Error otherwise.
 * @param {bool} cond The condition.
 * @param {String} message The error message issued if cond is false.
 */
life.Application.prototype.assert = function(cond, message) {
  if (!cond) {
    message = "Assertion failed: " + message;
    alert(message);
    throw new Error(message);
  }
}

/**
 * The run() method starts and 'runs' the application.  An <embed> tag is
 * injected into the <div> element |opt_viewDivName| which causes the Ginsu NaCl
 * module to be loaded.  Once loaded, the moduleDidLoad() method is called.
 * @param {?String} opt_viewDivName The id of a DOM element in which to
 *     embed the Ginsu module.  If unspecified, defaults to DomIds_.VIEW.  The
 *     DOM element must exist.
 */
life.Application.prototype.run = function(opt_viewDivName) {
  var viewDivName = opt_viewDivName || life.Application.DomIds_.VIEW;
  var viewDiv = goog.dom.$(viewDivName);
  this.assert(viewDiv, "Missing DOM element '" + viewDivName + "'");
  // This assumes that the <div> containers for Life modules each have a
  // unique name on the page.
  var uniqueModuleName = viewDivName + life.Application.DomIds_.MODULE;
  // This is a bit of a hack: when the |onload| event fires, |this| is set to
  // the DOM window object, *not* the <embed> element.  So, we keep a global
  // pointer to |this| because there is no way to make a closure here. See
  // http://code.google.com/p/nativeclient/issues/detail?id=693
  loadingLifeApp_[uniqueModuleName] = this;
  var onLoadJS = "loadingLifeApp_['"
               + uniqueModuleName
               + "'].moduleDidLoad(document.getElementById('"
               + uniqueModuleName
               + "'));"
  var viewSize = goog.style.getSize(viewDiv);
  viewDiv.innerHTML = '<embed  id="' + uniqueModuleName + '" ' +
                       ' class="autosize"' +
                       ' width=' + viewSize.width +
                       ' height=' + viewSize.height +
                       ' nacl="life.nmf"' +
                       ' type="application/x-nacl"' +
                       'onload="' + onLoadJS + '" />'
}

/**
 * Shut down the application instance.  This unhooks all the event listeners
 * and deletes the objects created in moduleDidLoad().
 */
life.Application.prototype.terminate = function() {
  goog.events.removeAll();
  this.viewController_ = null;
}

