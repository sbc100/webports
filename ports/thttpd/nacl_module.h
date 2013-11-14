/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#ifndef NACL_MODULE_H_
#define NACL_MODULE_H_
#include <fcntl.h>
#include <unistd.h>

#include <cstdio>
#include <stdexcept>
#include <string>
#include <typeinfo>

#include "ppapi/cpp/instance.h"
#include "ppapi/cpp/module.h"
#include "ppapi/cpp/var.h"

/// The Instance class.  One of these exists for each instance of your NaCl
/// module on the web page.  The browser will ask the Module object to create
/// a new Instance for each occurence of the <embed> tag that has these
/// attributes:
///     type="application/x-nacl"
///     src="thttpd.nmf"
/// To communicate with the browser, you must override HandleMessage() for
/// receiving messages from the borwser, and use PostMessage() to send messages
/// back to the browser.  Note that this interface is entirely asynchronous.
class ThttpdInstance
  : public pp::Instance {
  static ThttpdInstance* instance_;
 public:
  /// The constructor creates the plugin-side instance.
  /// @param[in] instance the handle to the browser-side plugin instance.
  explicit ThttpdInstance(PP_Instance instance);
  static ThttpdInstance* getInstance() { return instance_; }
  void MakeUpFiles();
  virtual void HandleMessage(const pp::Var& var_message);

 protected:
  pthread_t thread_;
};

class ThttpdModule
  : public pp::Module {
 public:
  ThttpdModule() {}
  virtual ~ThttpdModule() {}
  virtual pp::Instance* CreateInstance(PP_Instance instance);
};

#endif
