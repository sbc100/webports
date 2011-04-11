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
goog.require('goog.array');
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
 * The automaton rule string.  It is expressed as SSS/BB, where S is the
 * neighbour count that keeps a cell alive, and B is the count that causes a
 * cell to become alive.  See the .LIF 1.05 section in
 * http://psoup.math.wisc.edu/mcell/ca_files_formats.html for more info.
 * @default 23/3 the "Normal" Conway rules.
 * @type {Object.<Array>}
 * @private
 */
life.Application.prototype.automatonRules_ = {
  birthRule: [3],
  keepAliveRule: [2, 3]
};

/**
 * The id of the current stamp.  Defaults to the DEFAULT_STAMP_ID.
 * @type {string}
 * @private
 */
life.Application.prototype.currentStampId_ =
    life.controllers.ViewController.DEFAULT_STAMP_ID;

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

  // Set up the stamp editor.
  var stampEditorElement = document.getElementById('stamp_editor_button');
  this.stampEditor_ = new stamp.Editor(stampEditorElement);
  var stampEditorElements = {
    mainPanel: document.getElementById('stamp_editor_panel'),
    editorContainer: document.getElementById('stamp_editor_container'),
    addColumnButton: document.getElementById('add_column_button'),
    removeColumnButton: document.getElementById('remove_column_button'),
    addRowButton: document.getElementById('add_row_button'),
    removeRowButton: document.getElementById('remove_row_button'),
    cancelButton: document.getElementById('cancel_button'),
    okButton: document.getElementById('ok_button')
  };
  this.stampEditor_.makeStampEditorPanel(stampEditorElements);

  // Set up the view controller, it contains the NaCl module.
  this.viewController_ = new life.controllers.ViewController(nativeModule);
  this.viewController_.setAutomatonRules(this.automatonRules_);
  // Initialize the module with the default stamp.
  this.currentStampId_ = this.viewController_.DEFAULT_STAMP_ID;
  this.viewController_.makeStampCurrent(this.currentStampId_);

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

  var birthField = goog.dom.$(life.Application.DomIds_.BIRTH_FIELD);
  if (birthField) {
    goog.events.listen(birthField, goog.events.EventType.CHANGE,
        this.updateBirthRule, false, this);
  }

  var keepAliveField = goog.dom.$(life.Application.DomIds_.KEEP_ALIVE_FIELD);
  if (keepAliveField) {
    goog.events.listen(keepAliveField, goog.events.EventType.CHANGE,
        this.updateKeepAliveRule, false, this);
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
 * Read the text input and change it from a comma-separated list into a string
 * of the form BB, where B is a digit in [0..9] that represents the neighbour
 * count that causes a cell to come to life.
 * @param {!goog.events.Event} changeEvent The CHANGE event that triggered this
 *     handler.
 */
life.Application.prototype.updateBirthRule = function(changeEvent) {
  changeEvent.stopPropagation();
  var birthRule = this.parseAutomatonRule_(changeEvent.target.value);
  // Put the sanitized version of the rule string back into the text field.
  changeEvent.target.value = birthRule.join(',');
  // Make the new rule string and tell the NaCl module.
  this.automatonRules_.birthRule = birthRule;
  this.viewController_.setAutomatonRules(this.automatonRules_);
}

/**
 * Read the text input and change it from a comma-separated list into a string
 * of the form SSS, where S is a digit in [0..9] that represents the neighbour
 * count that allows a cell to stay alive.
 * @param {!goog.events.Event} changeEvent The CHANGE event that triggered this
 *     handler.
 */
life.Application.prototype.updateKeepAliveRule = function(changeEvent) {
  changeEvent.stopPropagation();
  var keepAliveRule = this.parseAutomatonRule_(changeEvent.target.value);
  // Put the sanitized version of the rule string back into the text field.
  changeEvent.target.value = keepAliveRule.join(',');
  // Make the new rule string and tell the NaCl module.
  this.automatonRules_.keepAliveRule = keepAliveRule;
  this.viewController_.setAutomatonRules(this.automatonRules_);
}

/**
 * Parse a user-input string representing an automaton rule into an array of
 * neighbour counts.  |ruleString| is expected to be a comma-separated string
 * of integers in range [0..9].  This routine attempts to sanitize non-
 * conforming values by clipping (numbers outside [0..9] are clipped), and
 * replaces non-numberic input with 0.  The resulting array is sorted, and each
 * value is unique.  For example: '1,3,2,2' will produce [1, 2, 3].
 * @param {!string} ruleString The user-input string.
 * @return {Array.<number>} An array of neighbour counts that can be used to
 *    create an automaton rule.
 * @private
 */
life.Application.prototype.parseAutomatonRule_ = function(ruleString) {
  var rule = ruleString.split(',');

  /**
   * Helper function to parse a single rule element: trim off any leading or
   * trailing white-space, then attempt to convert the resulting string into
   * an integer.  Clip the integer to range [0..8].  Replace the element in
   * |array| with the resulting number.  Note: non-numeric values are replaced
   * with 0.
   * @param {string} ruleString The string to parse.
   * @param {number} index The index of the element in the original array.
   * @param {Array} ruleArray The array of rules.
   */
  function parseOneRule(ruleString, index, ruleArray) {
    var neighbourCount = parseInt(ruleString.trim());
    if (isNaN(neighbourCount) || neighbourCount < 0)
      neighbourCount = 0;
    if (neighbourCount > 8)
      neighbourCount = 8;
    ruleArray[index] = neighbourCount;
  }

  // Each rule has to be an integer in [0..8]
  goog.array.forEach(rule, parseOneRule, this);
  // Sort the rules numerically.
  rule.sort(function(a, b) { return a - b; });
  goog.array.removeDuplicates(rule);
  return rule;
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

/**
 * Extend the String class to trim whitespace.
 * @return {string} the original string with leading and trailing whitespace
 *     removed.
 */
String.prototype.trim = function () {
  return this.replace(/^\s*/, '').replace(/\s*$/, '');
}
