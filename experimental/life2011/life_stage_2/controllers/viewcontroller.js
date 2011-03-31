// Copyright 2011 (c) The Native Client Authors.  All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/**
 * @fileoverview  Implement the view controller class, ViewController, that
 * owns the Life NaCl module and wraps JavaScript bridge calls to it.  This
 * class also handles certain UI interactions, such as mouse drags and keyboard
 * shortcuts.
 */

goog.provide('life.controllers.ViewController');

goog.require('goog.Disposable');
goog.require('goog.dom');
goog.require('goog.events.EventTarget');
goog.require('goog.fx.DragEvent');
goog.require('goog.object');
goog.require('goog.style');
goog.require('uikit.events.Dragger');

/**
 * Constructor for the ViewController class.  This class encapsulates the
 * Life NaCl module in a view.  It also produces some UI events, such as mouse
 * drags.
 * @param {!Object} nativeModule The DOM element that represents a
 *      ViewController (usually the <EMBED> element that contains the NaCl
 *      module).  If undefined, an error is thrown.
 * @constructor
 * @extends {goog.events.EventTarget}
 */
life.controllers.ViewController = function(nativeModule) {
  goog.events.EventTarget.call(this);
  /**
   * The element containing the Life NaCl module that corresponds to
   * this object instance.  If null or undefined, an exception is thrown.
   * @type {Element}
   * @private
   */
  if (!nativeModule) {
    throw new Error('ViewController() requries a valid NaCl module');
  }
  // The container is the containing DOM element.
  this.module_ = nativeModule;

  /**
   * Mouse drag event object.
   * @type {life.events.Dragger}
   * @private
   */
  this.dragListener_ = new uikit.events.Dragger(nativeModule);
  // Hook up a Dragger and listen to the drag events coming from it, then
  // reprocess the events as Ginsu DRAG events.
  goog.events.listen(this.dragListener_, goog.fx.Dragger.EventType.START,
      this.handleStartDrag_, false, this);
  goog.events.listen(this.dragListener_, goog.fx.Dragger.EventType.END,
      this.handleEndDrag_, false, this);
  goog.events.listen(this.dragListener_, goog.fx.Dragger.EventType.DRAG,
      this.handleDrag_, false, this);
};
goog.inherits(life.controllers.ViewController, goog.events.EventTarget);

/**
 * Override of disposeInternal() to unhook all the listeners and dispose
 * of retained objects.
 * @override
 */
life.controllers.ViewController.prototype.disposeInternal = function() {
  life.controllers.ViewController.superClass_.disposeInternal.call(this);
  goog.events.unlisten(this.dragListener_, goog.fx.Dragger.EventType.START,
      this.handleStartDrag_, false, this);
  goog.events.unlisten(this.dragListener_, goog.fx.Dragger.EventType.DRAG,
      this.handleDrag_, false, this);
  goog.events.unlisten(this.dragListener_, goog.fx.Dragger.EventType.END,
      this.handleEndDrag_, false, this);
  this.dragListener_ = null;
  this.module_ = null;
};

/**
 * Method to get the bounding frame rectangle for the DOM container.
 * @return {Object} The bounding frame expressed in the coordinate space
 *     of this view.
 */
life.controllers.ViewController.prototype.frame = function() {
  var containerSize = goog.style.getSize(this.module_);
  return {x: 0, y: 0, width: containerSize.width, height: containerSize.height};
};

/**
 * Handle the drag START event: add a cell at the event's coordinates.
 * @param {!goog.fx.DragEvent} dragStartEvent The START event that
 *     triggered this handler.
 * @private
 */
life.controllers.ViewController.prototype.handleStartDrag_ =
    function(dragStartEvent) {
  dragStartEvent.stopPropagation();
  this.module_.addCellAtPoint(dragStartEvent.clientX, dragStartEvent.clientY);
};

/**
 * Handle the DRAG event: add a cell at the event's coordinates.
 * @param {!goog.fx.DragEvent} dragEvent The DRAG event that triggered this
 *     handler.
 * @private
 */
life.controllers.ViewController.prototype.handleDrag_ = function(dragEvent) {
  dragEvent.stopPropagation();
  this.module_.addCellAtPoint(dragEvent.clientX, dragEvent.clientY);
};

/**
 * Handle the drag END event: stop propagating the event.
 * @param {!goog.fx.DragEvent} dragEndEvent The END event that triggered this
 *     handler.
 * @private
 */
life.controllers.ViewController.prototype.handleEndDrag_ =
    function(dragEndEvent) {
  dragEndEvent.stopPropagation();
};

/**
 * Handle keyboard shortcut events.  These get transformed into Ginsu app
 * events and re-dispatched.
 * @param {!goog.ui.KeyboardShortcutEvent} keyboardEvent The SHORTCUT event
 * that triggered this handler.
 * @private
 */
life.controllers.ViewController.prototype.handleKeyboard_ =
    function(keyboardEvent) {
  var eventClone = goog.object.clone(keyboardEvent);
  keyboardEvent.stopPropagation();
  this.dispatchEvent(new life.events.Event(life.events.EventType.ACTION, this,
      keyboardEvent.identifier));
};
