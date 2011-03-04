// Copyright 2011 The Native Client SDK Authors.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

/**
 * @file
 * The life Application object.  This object instantiates a Dragger object and
 * connects it to the element named @a life_module.
 */

// Requires life
// Requires uikit.Dragger

// The life namespace
var life = life || {};

/**
 * Constructor for the Application class.  Use the run() method to populate
 * the object with controllers and wire up the events.
 * @constructor
 */
life.Application = function() {
}

/**
 * The ids used for query parameter keys.
 * @enum {string}
 */
life.Application.QueryParameters = {
  BACKGROUND: 'background'  // The URL for the background image.
};

/**
 * The native module for the application.  This refers to the module loaded via
 * the <embed> tag.
 * @type {Element}
 * @private
 */
life.Application.prototype.module_ = null;

/**
 * The mouse-drag event object.
 * @type {tumbler.Dragger}
 * @private
 */
life.Application.prototype.dragger_ = null;

/**
 * The timer update interval object.
 * @type {tumbler.Dragger}
 * @private
 */
life.Application.prototype.updateInterval_ = null;

/**
 * Called by the module loading function once the module has been loaded. Wire
 * up a Dragger object to @a this.
 * @param {!Element} nativeModule The instance of the native module.
 * @param {?String} opt_appUrl The full URL, including query parameters, used to
 *     load this application.
 * @param {?String} opt_contentDivId The id of a DOM element which captures
 *     the UI events.  If unspecified, defaults to DEFAULT_DIV_ID.  The DOM
 *     element must exist.
 */
life.Application.prototype.moduleDidLoad =
    function(nativeModule, opt_appUrl, opt_contentDivId) {
  contentDivId = opt_contentDivId || life.Application.DEFAULT_DIV_ID;
  var contentDiv = document.getElementById(contentDivId);
  this.module_ = nativeModule;
  this.dragger_ = new uikit.Dragger(contentDiv);
  this.dragger_.addDragListener(this);
  if (this.module_) {
    if (opt_appUrl) {
      // Get the background image URL form the query parameters and load it.
      var urlParams = this.getUrlParameters(opt_appUrl);
      if (life.Application.QueryParameters.BACKGROUND in urlParams) {
        this.module_.imageUrl =
            urlParams[life.Application.QueryParameters.BACKGROUND];
      }
    }
    // Use a 10ms update interval to drive frame rate
    this.updateInterval_ = setInterval("life.application.update()", 10);
  }
}

/**
 * Called when the page is unloaded.
 */
life.Application.prototype.moduleDidUnload = function() {
  clearInterval(this.updateInterval_);
}

/**
 * Return a dictionary that represents the query parameters of @a fullUrl.
 * Note that the query parameters _must_ be 'key=value&...' pairs separated
 * by the '&' character, this function does not handle simple "boolean"
 * query parameters such as 'bool_key&...'.  For example, the URL
 *   http://www.example.com/life.html?background=spear.jpg
 * will produce a dictionary like this:
 *   dict['background'] <= 'spear.jpg'
 * @param {!string} fullUrl The entire URL, including query parameters.
 * @return {Object} A dictionary (a "hash") whose keys are the keys in
 *     @fullUrl; values are the values assigned to those keys.
 */
life.Application.prototype.getUrlParameters = function(fullUrl) {
  var queryString = fullUrl.slice(window.location.href.indexOf('?') + 1);
  var keyValuePairs = queryString.split('&');
  var parameterDict = [];
  for (var i = 0; i < keyValuePairs.length; ++i) {
    var keyValue = keyValuePairs[i].split('=');
    parameterDict.push(keyValue[0]);
    parameterDict[keyValue[0]] = keyValue[1];
  }
  return parameterDict;
}

/**
 * Called from the interval timer.  This is a simple wrapper to call the
 * "update" method on the Life NaCl module.
 */
life.Application.prototype.update = function() {
  if (this.module_)
    this.module_.update();
}

/**
 * Add a simulation cell at a 2D point.
 * @param {!number} point_x The x-coordinate, relative to the origin of the
 *     enclosing element.
 * @param {!number} point_y The y-coordinate, relative to the origin of the
 *     enclosing element, y increases downwards.
 */
life.Application.prototype.AddCellAtPoint = function(point_x, point_y) {
  if (this.module_)
    this.module_.addCellAtPoint(point_x, point_y);
}

/**
 * Handle the drag START event: Drop a new life cell at the mouse location.
 * @param {!life.Application} view The view controller that called
 *     this method.
 * @param {!uikit.DragEvent} dragStartEvent The DRAG_START event that
 *     triggered this handler.
 */
life.Application.prototype.handleStartDrag =
    function(controller, dragStartEvent) {
  this.AddCellAtPoint(dragStartEvent.clientX, dragStartEvent.clientY);
}

/**
 * Handle the drag DRAG event: Drop a new life cell at the mouse location.
 * @param {!life.Application} view The view controller that called
 *     this method.
 * @param {!uikit.DragEvent} dragEvent The DRAG event that triggered
 *     this handler.
 */
life.Application.prototype.handleDrag = function(controller, dragEvent) {
  this.AddCellAtPoint(dragEvent.clientX, dragEvent.clientY);
}

/**
 * Handle the drag END event: This is a no-op.
 * @param {!life.Application} view The view controller that called
 *     this method.
 * @param {!uikit.DragEvent} dragEndEvent The DRAG_END event that
 *     triggered this handler.
 */
life.Application.prototype.handleEndDrag = function(controller, dragEndEvent) {
}

/**
 * The default name for the Life module EMBED element.
 * @type {string}
 */
life.Application.DEFAULT_DIV_ID = 'life_module';
