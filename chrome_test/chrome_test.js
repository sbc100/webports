/*
 * Copyright (c) 2014 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

'use strict';

// Utilities to allow googletest style tests of apps / extensions.


/**
 * @namespace.
 */
var chrometest = {};

/**
 * @private
 */
chrometest.passed_ = null;
chrometest.currentTest_ = null;
chrometest.currentTestName_ = null;
chrometest.startTime_ = null;
chrometest.finishTest_ = null;
chrometest.tests_ = [];

/**
 * @private
 * @constant
 */
chrometest.ERROR = 'ERROR';
chrometest.WARNING = 'WARNING';
chrometest.INFO = 'INFO';
chrometest.DEBUG = 'DEBUG';


/**
 * Get the decoded query parameters passed to the current page.
 * @return {Object.<string>}.
 */
chrometest.getUrlParameters = function() {
  var items = {};
  if (window.location.search.length < 1) {
    return items;
  }
  var fields = window.location.search.slice(1).split('&');
  for (var i = 0; i < fields.length; i++) {
    var parts = fields[i].split('=');
    items[decodeURIComponent(parts[0])] = decodeURIComponent(parts[1]);
  }
  return items;
};

/**
 * Create a new messaging port to communicate with the testing extension.
 * @return {Port}.
 */
chrometest.newTestPort = function() {
  var parts = navigator.userAgent.split('/');
  var extensionId = parts[1];
  return chrome.runtime.connect(extensionId);
};

/**
 * Kill the browser (to end the testing session).
 */
chrometest.haltBrowser = function() {
  var port = chrometest.newTestPort();
  port.postMessage({'name': 'haltBrowser'});
};

/**
 * Reset the connection in the testing extension.
 * @param {function(integer)} callback Called on completion with a count of the
 *                                     number of connections killed.
 */
chrometest.resetExtension = function(callback) {
  var port = chrometest.newTestPort();
  var count = null;
  port.onMessage.addListener(function(msg) {
    port.disconnect();
    callback(msg.count);
  });
  port.postMessage({'name': 'reset'});
}

/**
 * Get a list of all loaded extensions.
 *
 * This exposes the result of chrome.management.getAll for use by tests.
 * @returns {Array.<ExtensionInfo>}.
 */
chrometest.getAllExtensions = function(callback) {
  var port = chrometest.newTestPort();
  port.onMessage.addListener(function(msg) {
    port.disconnect();
    callback(msg.result);
  });
  port.postMessage({'name': 'getAllExtensions'});
};

/**
 * Get a mapping of process id to process info for all processes running.
 *
 * This exposes the result of chrome.processes.getProcessInfo for use by tests.
 * @return {Object.<ProcessInfo>}.
 */
chrometest.getAllProcesses = function(callback) {
  var port = chrometest.newTestPort();
  port.onMessage.addListener(function(msg) {
    port.disconnect();
    callback(msg.result);
  });
  port.postMessage({'name': 'getAllProcesses'});
};

/**
 * Create a messaging port to communicate with an extension by name.
 *
 * Ordinarily web pages can only communicate with extensions that have
 * explicitly ask for permission in their manifests. However, extensions can
 * communicate with each other without this, but should endeavor to verify that
 * they only communicate with trusted peers. The testing extension should be
 * whitelisted by the extensions under test when in testing mode. This allows
 * the testing extension to offer web pages proxied access to extensions under
 * test without modification.
 * @returns {Port}.
 */
chrometest.proxyExtension = function(extensionName, callback) {
  var port = chrometest.newTestPort();
  function handleProxyReply(msg) {
    port.onMessage.removeListener(handleProxyReply);
    ASSERT_EQ('proxyReply', msg.name, 'expect proxy reply');
    ASSERT_TRUE(
        msg.success, 'should find one extension: ' + extensionName +
        ' found ' + msg.matchCount);
    callback(port);
  }
  port.onMessage.addListener(handleProxyReply);
  port.postMessage({'name': 'proxy', 'extension': extensionName});
};

/**
 * Log a message to the test harness.
 * @param {string} level The python logging level of the message.
 * @param {string} message The message to log.
 * @param {function()} opt_callback Called on completion.
 */
chrometest.log = function(level, message, opt_callback) {
  var r = new XMLHttpRequest();
  r.open('GET', '/_command?log=' + encodeURIComponent(message) +
         '&level=' + encodeURIComponent(level), false);
  r.onload = function() {
    if (r.readyState == 4) {
      if (opt_callback !== undefined) {
        opt_callback(r.status);
      }
    }
  }
  r.send();
};

/**
 * Log an error message.
 * @param {string} message The message to log.
 * @param {function()} opt_callback Called on completion.
 */
chrometest.error = function(message, opt_callback) {
  chrometest.log(chrometest.ERROR, message, opt_callback);
};

/**
 * Log a warning message.
 * @param {string} message The message to log.
 * @param {function()} opt_callback Called on completion.
 */
chrometest.warning = function(message, opt_callback) {
  chrometest.log(chrometest.WARNING, message, opt_callback);
};

/**
 * Log an info message.
 * @param {string} message The message to log.
 * @param {function()} opt_callback Called on completion.
 */
chrometest.info = function(s, opt_callback) {
  chrometest.log(chrometest.INFO, message, opt_callback);
};

/**
 * Log a debug message.
 * @param {string} message The message to log.
 * @param {function()} opt_callback Called on completion.
 */
chrometest.debug = function(message, opt_callback) {
  chrometest.log(chrometest.DEBUG, message, opt_callback);
};

/**
 * Perform an HTTP GET.
 * @param {string} url The URL to fetch.
 * @param {function()} callback The call called with (status, responseText) on
 *                            completion.
 */
chrometest.httpGet = function(url, callback) {
  var r = new XMLHttpRequest();
  r.open('GET', url, false);
  r.onload = function() {
    if (r.readyState == 4) {
      callback(r.status, r.responseText);
    }
  }
  r.send();
};

/**
 * Format a time in milliseconds to XXms or YYs as appropriate.
 * @param {float} ms Time in milliseconds.
 * @return {string} A formatted time.
 */
chrometest.formatDuration = function(ms) {
  if (ms < 1000.0) {
    return ms + 'ms';
  } else {
    return (ms / 1000.0).toFixed(1) + 's';
  }
};

/**
 * Tell the test harness how many test runs to expect.
 * @param {integer} testCount The number of tests to expect.
 */
chrometest.reportTestCount_ = function(testCount, callback) {
  console.log('About to run ' + testCount + ' tests.');
  chrometest.httpGet(
      '/_command?test_count=' + testCount, callback);
};

/**
 * Notify the test harness that a test has begun.
 * @param {string} name The full name of the test.
 * @param {function()} callback Called on completion.
 */
chrometest.beginTest_ = function(name, callback) {
  chrometest.resetExtension(function(count) {
    if (count != 0) {
      chrometest.error(
          'Test extension connections from the last test remain active!',
          function() {
        chrometest.haltBrowser();
      });
    }
    console.log('[ RUN      ] ' + name);
    chrometest.passed_ = true;
    chrometest.currentTestName_ = name;
    chrometest.httpGet(
        '/_command?name=' + encodeURIComponent(name) +
        '&start=1', function() {
      chrometest.startTime_ = new Date();
      callback();
    });
  });
};

/**
 * Notify the test harness that a test has ended.
 * @param {function()} callback  called on completion.
 */
chrometest.endTest_ = function(callback) {
  chrometest.resetExtension(function(count) {
    EXPECT_EQ(0, count,
              'all connection to the test extension should be closed');
    var endTime = new Date();
    var duration = endTime.getTime() - chrometest.startTime_.getTime();
    duration = chrometest.formatDuration(duration);
    var name = chrometest.currentTestName_;
    if (chrometest.passed_) {
      var resultMsg = '      OK';
      var result = 1;
    } else {
      var resultMsg = ' FAILED ';
      var result = 0;
    }
    console.log('[ ' + resultMsg + ' ] ' + name + ' (' + duration + ')');
    chrometest.startTime_ = null;
    chrometest.currentTest_ = null;
    chrometest.currentTestName_ = null;
    chrometest.httpGet(
        '/_command?name=' + encodeURIComponent(name) + '&' +
        'duration=' + encodeURIComponent(duration) + '&' +
        'result=' + result, callback);
  });
};

/**
 * Mark current test as failed.
 */
chrometest.fail = function() {
  chrometest.passed_ = false;
};

/**
 * Assert that something must be true to continue the current test.
 *
 * This halts the current test by throwing an exception.
 * Unfortunately, this has the danger that it may not actually halt the test.
 * Ideally, any exception handling in the test itself should be done very
 * carefully to ensure it passes along 'assert' exceptions.
 * If the code under test eats the exception, at least the test will be marked
 * as failed. If the exception causes the code under test to wait indefinitely,
 * the timeout in the testing harness will eventually bring everything down.
 *
 * Halts the current test if the condition is not true.
 * @param {boolean} condition A condition to check.
 * @param {string} description A description of the context in which the
 *                             condition is being checked (to help
 *                             label / find it).
 */
chrometest.assert = function(condition, description) {
  if (!condition) {
    chrometest.fail();
    if (description == null) {
      description = 'no description';
    }
    var error = new Error('ASSERT FAILED! - ' + description);
    chrometest.error(error.stack, function() {
      throw 'assert';
    });
  }
};

/**
 * Declare that something must be true for the current test to pass.
 *
 * Does not halt the current test if the condition is false, but does emit
 * information on the failure location and mark the test as failed.
 * @param {boolean} condition A condition to check.
 * @param {string} description A description of the context in which the
 *                             condition is being checked (to help
 *                             label / find it).
 */
chrometest.expect = function(condition, description) {
  if (!condition) {
    chrometest.fail();
    if (description == null) {
      description = 'no description';
    }
    var error = new Error('EXPECT FAILED! - ' + description);
    chrometest.error(error.stack, function() {});
  }
};

/**
 * Run a list of tests.
 * param {Array.<Test>} testList The list of tests to run.
 * param {function()} callback Called on completion.
 */
chrometest.runTests_ = function(testList, callback) {
  if (testList.length == 0) {
    callback();
  } else {
    var rest = testList.slice(1);
    testList[0].call(function() {
      chrometest.runTests_(rest, callback);
    });
  }
};

/**
 * Check if a string matches a wildcard string.
 * @param string filter A wildcard string (* - any string, ? - one char).
 * @param string s A string to match.
 */
chrometest.wildcardMatch = function(filter, s) {
  filter = filter.replace(/[.]/g, '[.]');
  filter = filter.replace(/\*/g, '.*');
  filter = filter.replace(/\?/g, '.');
  filter = '^' + filter + '$';
  var re = new RegExp(filter);
  return re.test(s);
};

/**
 * Check if a string matches a googletest style filter.
 * A filter consists of zero or more ':' separated positive wildcard
 * strings, followed optionally by a '-' and zero or more ':' separated
 * negative wildcard strings.
 * @param string filter A googletest style filter string.
 * @param string s A string to match.
 */
chrometest.filterMatch = function(filter, s) {
  var parts = filter.split('-');
  if (parts.length == 1) {
    var positive = parts[0].split(':');
    var negative = [];
  } else if (parts.length == 2) {
    var positive = parts[0].split(':');
    var negative = parts[1].split(':');
  } else {
    // Treat ill-formated filters as non-matches.
    return false;
  }
  if (positive.length == 1 && positive[0] == '') {
    positive = ['*'];
  }
  if (negative.length == 1 && negative[0] == '') {
    negative = [];
  }
  for (var i = 0; i < positive.length; i++) {
    if (!chrometest.wildcardMatch(positive[i], s)) {
      return false;
    }
  }
  for (var i = 0; i < negative.length; i++) {
    if (chrometest.wildcardMatch(negative[i], s)) {
      return false;
    }
  }
  return true;
};

/**
 * Filter tests based on harness filter.
 * param {function()} callback Called on completion.
 */
chrometest.filterTests_ = function(callback) {
  chrometest.httpGet('/_command?filter=1', function(responseCode, filter) {
    if (responseCode != 200) {
      chrometest.error(
          'Requesting filter from test harness failed!', function() {
        chrometest.haltBrowser();
      });
      return;
    }
    var keep = [];
    var tests = chrometest.tests_;
    for (var i = 0; i < tests.length; i++) {
      if (chrometest.filterMatch(filter, tests[i].name)) {
        keep.push(tests[i]);
      }
    }
    chrometest.tests_ = keep;
    callback();
  });
};

/**
 * Report the test count and run all register tests and halt the browser.
 */
chrometest.runAllTests_ = function() {
  chrometest.filterTests_(function() {
    // Wait 100ms before starting the tests as extensions may not load
    // simultaneously.
    setTimeout(function() {
      chrometest.reportTestCount_(chrometest.tests_.length, function() {
        chrometest.runTests_(chrometest.tests_, function() {
          chrometest.haltBrowser();
        });
      });
    });
  }, 100);
};

/**
 * Load a list of javascript files into script tags.
 * @param {Array.<string>} sources A list of javascript files to load tests
 *                                 from.
 */
chrometest.run = function(sources) {
  window.onerror = function(
      errorMsg, url, lineNumber, columnNumber, error) {
    chrometest.fail();
    chrometest.error(
        errorMsg + ' in ' + url + ' at ' +
        lineNumber + ':' + columnNumber + '\n' + error.stack, function() {
      chrometest.haltBrowser();
    });
  };
  var fileCount = 0;
  for (var i = 0; i < sources.length; i++) {
    var script = document.createElement('script');
    script.src = sources[i];
    script.onerror = function(e) {
      chrometest.error('Error loading ' + e.target.src + '\n', function() {
        chrometest.haltBrowser();
      });
    };
    script.onload = function() {
      fileCount++;
      if (fileCount == sources.length) {
        chrometest.runAllTests_();
      }
    }
    document.body.appendChild(script);
  }
};


/**
 * A test case.
 * @constructor
 */
chrometest.Test = function() {
};

/**
 * The default setUp method for a test case (does nothing).
 * @param {function()} done Called on completion.
 */
chrometest.Test.prototype.setUp = function(done) {
  done();
};

/**
 * The default tearDown method for a test case (does nothing).
 * @param {function()} done Called on completion.
 */
chrometest.Test.prototype.tearDown = function(done) {
  done();
};


// Below this point functions are declare at global scope and use a naming
// convention that matches googletest. This done for several reasons:
//   - A global name makes use through multiple tests convenient.
//   - Using an existing naming convention makes use and intent clear.
//   - ALL CAPS highlights the testing constructs visually.


// TEST Types
// ----------

/**
 * Register a test case using a fixture class.
 * @param {string} fixtureClass The test fixture class object.
 * @param {string} testName The name of the test.
 * @param {function(done)} testFunc Called to run the test, calls done on
 *                                  completion.
 * @param {string} opt_caseName Optional name for the case, otherwise the
 *                              fixtureClass class name is used.
 */
function TEST_F(fixtureClass, testName, testFunc, opt_caseName) {
  if (opt_caseName == undefined) {
    opt_caseName = fixtureClass.name;
  }
  var fullName = opt_caseName + '.' + testName;
  chrometest.tests_.push({
    'name': fullName,
    'call': function(next) {
      chrometest.beginTest_(fullName, function() {
        chrometest.finishTest_ = function() {
          chrometest.finishTest_ = function() {
            chrometest.finishTest_ = null;
            chrometest.endTest_(next);
          };
          chrometest.currentTest_.tearDown(chrometest.finishTest_);
        };
        chrometest.currentTest_ = new fixtureClass();
        chrometest.currentTest_.run = testFunc;
        window.onerror = function(
          errorMsg, url, lineNumber, columnNumber, error) {
            chrometest.fail();
            if (error == 'assert') {
              chrometest.finishTest_();
              return;
            }
            chrometest.error(error.stack, function() {
              chrometest.finishTest_();
            });
          };
        chrometest.currentTest_.setUp(function() {
          chrometest.currentTest_.run(chrometest.finishTest_);
        });
      });
    },
  });
}

/**
 * Register a single test.
 * @param {string} testCase A test case name in lieu of a fixture.
 * @param {string} testName The name of the test.
 * @param {function(done)} testFunc Called to run the test, calls done on
 *                                  completion.
 */
function TEST(testCase, testName, testFunc) {
  TEST_F(chrometest.Test, testName, testFunc, testCase);
}


// ASSERT VARIANTS
// ---------------

function ASSERT_EQ(expected, actual, context) {
  expected = JSON.stringify(expected);
  actual = JSON.stringify(actual);
  chrometest.assert(expected == actual, 'Expected ' + expected + ' but got ' +
                    JSON.stringify(actual) + ' when ' + context);
}

function ASSERT_NE(expected, actual, context) {
  expected = JSON.stringify(expected);
  actual = JSON.stringify(actual);
  chrometest.assert(expected != actual, 'Did not expect ' + expected +
                    ' but got ' + actual + ' when ' + context);
}

function ASSERT_TRUE(value, context) {
  ASSERT_EQ(true, value, context);
}

function ASSERT_FALSE(value, context) {
  ASSERT_EQ(false, value, context);
}

function ASSERT_LT(a, b, context) {
  chrometest.assert(a < b, 'Expected ' + a + ' < ' + b + ' when ' + context);
}

function ASSERT_GT(a, b, context) {
  chrometest.assert(a > b, 'Expected ' + a + ' > ' + b + ' when ' + context);
}

function ASSERT_LE(a, b, context) {
  chrometest.assert(a <= b, 'Expected ' + a + ' <= ' + b + ' when ' + context);
}

function ASSERT_GE(a, b, context) {
  chrometest.assert(a >= b, 'Expected ' + a + ' >= ' + b + ' when ' + context);
}


// EXPECT VARIANTS
// ---------------

function EXPECT_EQ(expected, actual, context) {
  expected = JSON.stringify(expected);
  actual = JSON.stringify(actual);
  chrometest.expect(expected == actual, 'Expected ' + expected + ' but got ' +
                    JSON.stringify(actual) + ' when ' + context);
}

function EXPECT_NE(expected, actual, context) {
  expected = JSON.stringify(expected);
  actual = JSON.stringify(actual);
  chrometest.expect(expected != actual, 'Did not expect ' + expected +
                    ' but got ' + actual + ' when ' + context);
}

function EXPECT_TRUE(value, context) {
  EXPECT_EQ(true, value, context);
}

function EXPECT_FALSE(value, context) {
  EXPECT_EQ(false, value, context);
}

function EXPECT_LT(a, b, context) {
  chrometest.expect(a < b, 'Expected ' + a + ' < ' + b + ' when ' + context);
}

function EXPECT_GT(a, b, context) {
  chrometest.expect(a > b, 'Expected ' + a + ' > ' + b + ' when ' + context);
}

function EXPECT_LE(a, b, context) {
  chrometest.expect(a <= b, 'Expected ' + a + ' <= ' + b + ' when ' + context);
}

function EXPECT_GE(a, b, context) {
  chrometest.expect(a >= b, 'Expected ' + a + ' >= ' + b + ' when ' + context);
}
