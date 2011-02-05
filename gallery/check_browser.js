// Copyright 2011 Google Inc. All Rights Reserved.

/**
 * @fileoverview This file provides a BrowserChecker Javascript class.
 * Users can create a BrowserChecker object, invoke checkBrowser(|version|),
 * and then use getIsValidBrowser() and getBrowserSupportMessage()
 * to determine if the browser version is greater than |version|
 * and if the Native Client plugin is found.
 */

// Create a namespace object
var browser_version = browser_version || {}


/**
 * Class to provide checking for version and NativeClient.
 * @param {integer} arg1 An argument that indicates major version of Chrome we
 *     require, such as 10.
 */

/**
 * Constructor for the BrowserChecker.  Sets the major version of
 * Chrome that is required to |requiredChromeVersion|.
 * @param requiredChromeVersion   The major version of chrome that
 *     is required.  If the Chrome browser version is less than
 *     |requiredChromeVersion| then |isValidBrowswer| will be set to false.
 * @param appVersion  The application version string.
 * @param plugins     The plugins that exist in the browser.
 * @constructor
 */
browser_version.BrowserChecker = function(requiredChromeVersion, appVersion,
                                          plugins) {

  /**
   * Version specified by the user. This class looks to see if the browser
   * version is >= |requiredChromeVersion_|.
   * @type {integer}
   * @private
   */
  this.requiredChromeVersion_ = requiredChromeVersion;

  /**
   * List of Browser plugin objects.
   * @type {Ojbect array}
   * @private
   */
  this.plugins_ = plugins;

  /**
   * Application version string from the Browser.
   * @type {integer}
   * @private
   */
  this.appVersion_ = appVersion;


  /**
   * Flag used to indicate if the browser has Native Client and is if the
   * browser version is recent enough.
   * @type {boolean}
   * @private
   */
  this.isValidBrowser_ = false;

  /**
   * Actual major version of Chrome -- found by querying the browser.
   * @type {integer}
   * @private
   */
  this.chromeVersion_ = null;

  /**
   * Message generated if Native Client is found and if 
   * there is not a version problem.
   * @type {string}
   * @private
   */
  this.browserSupportMessage_ = '???';
}

/**
 * Determines if the plugin with name |name| exists in the browser.
 * @param {string} name The name of the plugin.
 * @param {Object array} plugins The plugins in this browser.
 * @return {bool} |true| if the plugin is found.
 */
browser_version.BrowserChecker.prototype.pluginExists = function(name,
                                                                 plugins) {
  for (var index=0; index < plugins.length; index++) {
    var plugin = this.plugins_[index];
    var plugin_name = plugin["name"];
    // If the plugin is not found, you can use the Javascript console
    // to see the names of the plugins that were found when debugging.
    console.log("plugin name: " + plugin_name);
    if (plugin_name.indexOf(name) != -1) {
      return true;
    }
  }
  return false;
}

/**
 * Returns isValidBrowser (true/false) to indicate if the browser supports
 * Native Client.
 * @ return {bool} If this browser has NativeClient and correct version.
 */
browser_version.BrowserChecker.prototype.getIsValidBrowser = function() {
  return this.isValidBrowser_;
}

/**
 * Returns a message that indicates if the browser supports Native Client, 
 * possibly including information on what prevents this browser from
 * supporting it.
 * @ return {string} The string that can be displayed by the browser.
 */
browser_version.BrowserChecker.prototype.getBrowserSupportMessage = function() {
  return this.browserSupportMessage_;
}

/**
 * Extracts the Chrome version from this.appVersion_ to set
 * this.chromeVersion and checks that this.chromeVersion is >=
 * this.requiredChromeVersion.
 * In addition, checks for the "NaCl" plugin as a member of
 * this.plugins_.
 */
browser_version.BrowserChecker.prototype.checkBrowser = function() {
  var versionPatt = /Chrome\/(\d+)\.(\d+)\.(\d+)\.(\d+)/;
  var result = this.appVersion_.match(versionPatt);

  // |result| stores the Chrome version number.
  if (!result) {
    this.browserSupportMessage_ = "This non-Chrome browser does NOT "
      + " support Native Client.";
    this.isValidBrowser_ = false;
  } else {
    this.chromeVersion_ = result[1];
    // We know we have Chrome, check version and/or plugin named NaCl
    if (this.chromeVersion_ >= this.requiredChromeVersion_) {
      var found_nacl = this.pluginExists("NaCl", this.plugins_);
      if (found_nacl) {
        this.browserSupportMessage_ = "Native Client enabled"
          + " in Google Chrome version " + this.chromeVersion_ + ".";
        this.isValidBrowser_ = true;
      } else {
        this.browserSupportMessage_ = "Native Client not enabled!<BR>"
          + "To run Native Client modules, go to about:flags in a tab,<BR>"
          + "click the Enable button beneath the Native Client section,<BR>"
          + "and then scroll down to the bottom of the page and press<BR>"
          + " the 'Restart Now' button.<BR><BR>"
          + "For more information see "
          // TODO: Fix the link below when we have the new external site
          // BUG: http://code.google.com/p/nativeclient/issues/detail?id=1386
          + '<a href="http://code.google.com/p/nativeclient-sdk/wiki/'
          + 'HowTo_RunModules#Step_2:_Launch_the_browser_with_--enable-nacl">'
          + "Launch the browser with --enable-nacl</a>."
        this.isValidBrowser_ = false;
      }
    } else {
      this.browserSupportMessage_ = "Native Client cannot run"
        + " in version " + this.chromeVersion_ + ".<BR>"
        + " You need version " + this.requiredChromeVersion_
        + " or greater.";
      this.isValidBrowser_ = false;
    }
  }
}

