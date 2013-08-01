/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#ifndef NACL_MODULE_H_
#define NACL_MODULE_H_
#include <fcntl.h>
#include <nacl-mounts/base/BaseMount.h>
#include <nacl-mounts/base/KernelProxy.h>
#include <nacl-mounts/base/MainThreadRunner.h>
#include <nacl-mounts/base/MountManager.h>
#include <nacl-mounts/memory/MemMount.h>
#include <nacl-mounts/net/SocketSubSystem.h>
#include <nacl-mounts/pepper/PepperMount.h>
#include <nacl-mounts/util/DebugPrint.h>
#include <unistd.h>

#include <cstdio>
#include <stdexcept>
#include <string>
#include <typeinfo>

#include "jsdirectoryreader.h"
#include "mythread.h"
#include "ppapi/cpp/file_system.h"
#include "ppapi/cpp/instance.h"
#include "ppapi/cpp/module.h"
#include "ppapi/cpp/var.h"
#include "shelljob.h"

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
  : public pp::Instance
  , public MyThreadClass {
  KernelProxy* kp;
  pp::FileSystem* fs_;
  JSDirectoryReader reader_;
  MainThreadRunner* runner_;
  static ThttpdInstance* instance_;
 public:
  /// The constructor creates the plugin-side instance.
  /// @param[in] instance the handle to the browser-side plugin instance.
  explicit ThttpdInstance(PP_Instance instance)
    : pp::Instance(instance)
    , reader_(this) {
    this->runner_ = new MainThreadRunner(this);
    MakeUpFiles();
    MakeUpFs();
    instance_ = this;
  }
  static ThttpdInstance* getInstance() { return instance_; }
  virtual ~ThttpdInstance() { }
  void RunJob(ShellJob* job) { runner_->RunJob(job); }

  void MakeUpFiles();
  void MakeUpFs();
  void InternalThreadEntry();
  void setKernelProxy(KernelProxy* kp);
  /// Handler for messages coming in from the browser via postMessage().  The
  /// @a var_message can contain anything: a JSON string; a string that encodes
  /// method names and arguments; etc.  For example, you could use
  /// JSON.stringify in the browser to create a message that contains a method
  /// name and some parameters, something like this:
  ///   var json_message = JSON.stringify({ "myMethod" : "3.14159" });
  ///   nacl_module.postMessage(json_message);
  /// On receipt of this message in @a var_message, you could parse the JSON to
  /// retrieve the method name, match it to a function call, and then call it
  /// with the parameter.
  /// @param[in] var_message The message posted by the browser.
  virtual void HandleMessage(const pp::Var& var_message);
};

/// The Module class.  The browser calls the CreateInstance() method to create
/// an instance of your NaCl module on the web page.  The browser creates a new
/// instance for each <embed> tag with type="application/x-nacl".
class ThttpdModule
  : public pp::Module {
  MountManager* mm;
  Mount* mnt;
  KernelProxy* kp;
 public:
  ThttpdModule();

  virtual ~ThttpdModule() {}

  /// Create and return a ThttpdInstance object.
  /// @param[in] instance The browser-side instance.
  /// @return the plugin-side instance.
  virtual pp::Instance* CreateInstance(PP_Instance instance);
};

#endif
