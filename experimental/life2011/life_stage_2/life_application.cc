// Copyright 2011 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "experimental/life2011/life_stage_2/life_application.h"

#include <ppapi/c/pp_errors.h>
#include <ppapi/cpp/completion_callback.h>
#include <ppapi/cpp/var.h>

#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <map>
#include <sstream>
#include <string>

namespace {
const char* const kClearMethodId = "clear";
const char* const kPutStampAtPointMethodId = "putStampAtPoint";
const char* const kRunSimulationMethodId = "runSimulation";
const char* const kSetAutomatonRulesMethodId = "setAutomatonRules";
const char* const kSetCurrentStampMethodId = "setCurrentStamp";
const char* const kStopSimulationMethodId = "stopSimulation";

const int kSimulationTickInterval = 10;  // Measured in msec.
const uint32_t kBackgroundColor = 0xFFFFFFFF;  // Opaque white.

// Simulation modes.  These strings are matched by the browser script.
const char* const kRandomSeedModeId = "random_seed";
const char* const kStampModeId = "stamp";

// Return the value of parameter named |param_name| from |parameters|.  If
// |param_name| doesn't exist, then return an empty string.
std::string GetParameterNamed(
    const std::string& param_name,
    const scripting::MethodParameter& parameters) {
  scripting::MethodParameter::const_iterator i =
      parameters.find(param_name);
  if (i == parameters.end()) {
    return "";
  }
  return i->second;
}

// Return the int32_t equivalent of |str|.  All the usual C++ rounding rules
// apply.
int32_t StringAsInt32(const std::string& str) {
  std::istringstream cvt_stream(str);
  double double_val;
  cvt_stream >> double_val;
  return static_cast<int32_t>(double_val);
}

// Helper function to set the scripting exception.  Both |exception| and
// |except_string| can be NULL.  If |exception| is NULL, this function does
// nothing.
void SetExceptionString(pp::Var* exception, const std::string& except_string) {
  if (exception) {
    *exception = except_string;
  }
}

// Exception strings.  These are passed back to the browser when errors
// happen during property accesses or method calls.
const char* const kExceptionMethodNotAString = "Method name is not a string";
const char* const kExceptionNoMethodName = "No method named ";
const char* const kInsufficientArgs =
    "Insufficient number of arguments to method ";
const char* const kInvalidArgs = "Invalid arguments to method ";

// Called from the browser when the delay time has elapsed.  This routine
// runs a simulation update, then reschedules itself to run the next
// simulation tick.
void SimulationTickCallback(void* data, int32_t result) {
  life::LifeApplication* life_app = static_cast<life::LifeApplication*>(data);
  life_app->Update();
  if (life_app->is_running()) {
    pp::Module::Get()->core()->CallOnMainThread(
        kSimulationTickInterval,
        pp::CompletionCallback(&SimulationTickCallback, data),
        PP_OK);
  }
}

// Called from the browser when the 2D graphics have been flushed out to the
// device.
void FlushCallback(void* data, int32_t result) {
  static_cast<life::LifeApplication*>(data)->set_flush_pending(false);
}
}  // namespace

using scripting::ScriptingBridge;

namespace life {
LifeApplication::LifeApplication(PP_Instance instance)
    : pp::Instance(instance),
      graphics_2d_context_(NULL),
      flush_pending_(false),
      view_changed_size_(true) {
}

LifeApplication::~LifeApplication() {
  DestroyContext();
}

bool LifeApplication::Init(uint32_t /* argc */,
                           const char* /* argn */[],
                           const char* /* argv */[]) {
  return true;
}

pp::Var LifeApplication::GetInstanceObject() {
  // Add all the methods to the scripting bridge.
  // ==GoogleIO2011== Add clear callback here.
  ScriptingBridge::SharedMethodCallbackExecutor
      put_stamp_method(new scripting::MethodCallback<LifeApplication>(
          this, &LifeApplication::PutStampAtPoint));
  scripting_bridge_.AddMethodNamed(kPutStampAtPointMethodId, put_stamp_method);

  ScriptingBridge::SharedMethodCallbackExecutor
      run_sim_method(new scripting::MethodCallback<LifeApplication>(
          this, &LifeApplication::RunSimulation));
  scripting_bridge_.AddMethodNamed(kRunSimulationMethodId, run_sim_method);

  ScriptingBridge::SharedMethodCallbackExecutor
      set_auto_rules_method(new scripting::MethodCallback<LifeApplication>(
          this, &LifeApplication::SetAutomatonRules));
  scripting_bridge_.AddMethodNamed(kSetAutomatonRulesMethodId,
                                   set_auto_rules_method);

  ScriptingBridge::SharedMethodCallbackExecutor
      set_stamp_method(new scripting::MethodCallback<LifeApplication>(
          this, &LifeApplication::SetCurrentStamp));
  scripting_bridge_.AddMethodNamed(kSetCurrentStampMethodId, set_stamp_method);

  ScriptingBridge::SharedMethodCallbackExecutor
      stop_sim_method(new scripting::MethodCallback<LifeApplication>(
          this, &LifeApplication::StopSimulation));
  scripting_bridge_.AddMethodNamed(kStopSimulationMethodId, stop_sim_method);

  // Return the temporary shim that handles postMessage() to the browser.  The
  // browser takes over ownership of this object instance.
  PostMessageBridge* script_object = new PostMessageBridge(this);
  return pp::Var(this, script_object);
}

void LifeApplication::HandleMessage(const pp::Var& message) {
  if (!message.is_string())
    return;
  scripting_bridge_.InvokeMethod(message.AsString());
}

void LifeApplication::DidChangeView(const pp::Rect& position,
                                    const pp::Rect& /* clip */) {
  if (position.size().width() == width() &&
      position.size().height() == height())
    return;  // Size didn't change, no need to update anything.
  // Indicate that all the buffers need to be resized at the next Update()
  // call.
  view_changed_size_ = true;
  view_size_ = position.size();
  // Make sure the buffers get changed if the simulation isn't running.
  if (!is_running())
    Update();
}

void LifeApplication::Update() {
  if (flush_pending())
    return;  // Don't attempt to flush if one is pending.
  if (view_changed_size_) {
    // Create a new device context with the new size.
    DestroyContext();
    CreateContext(view_size_);
    // Delete the old pixel buffer and create a new one.
    life_simulation_.DeleteCells();
    if (graphics_2d_context_ != NULL) {
      shared_pixel_buffer_.reset(
          new pp::ImageData(this,
                            PP_IMAGEDATAFORMAT_BGRA_PREMUL,
                            graphics_2d_context_->size(),
                            false));
      set_flush_pending(false);
      uint32_t* pixels = static_cast<uint32_t*>(shared_pixel_buffer_->data());
      if (pixels) {
        const size_t size = width() * height();
        std::fill(pixels, pixels + size, kBackgroundColor);
      }
      life_simulation_.Resize(width(), height());
      life_simulation_.set_pixel_buffer(shared_pixel_buffer_);
    }
    view_changed_size_ = false;
  }
  if (is_running())
    life_simulation_.LifeSimulation();
  FlushPixelBuffer();
}

void LifeApplication::SetCurrentStamp(
    const scripting::ScriptingBridge& bridge,
    const scripting::MethodParameter& parameters) {
  std::string stamp_desc = GetParameterNamed("description", parameters);
  if (stamp_desc.length()) {
    stamp_.InitFromDescription(stamp_desc);
  }
}

void LifeApplication::Clear(
    const scripting::ScriptingBridge& bridge,
    const scripting::MethodParameter& parameters) {
  // Temporarily pause the the simulation while clearing the buffers.
  volatile Life::SimulationMode sim_mode = life_simulation_.simulation_mode();
  if (sim_mode != Life::kPaused)
    life_simulation_.set_simulation_mode(Life::kPaused);
  life_simulation_.ClearCells();
  uint32_t* pixel_buffer = static_cast<uint32_t*>(shared_pixel_buffer_->data());
  if (pixel_buffer) {
    const size_t size = width() * height();
    std::fill(pixel_buffer,
              pixel_buffer + size,
              kBackgroundColor);
  }
  Update();  // Flushes the buffer correctly.
  if (sim_mode != Life::kPaused)
    life_simulation_.set_simulation_mode(sim_mode);
}

void LifeApplication::SetAutomatonRules(
    const scripting::ScriptingBridge& bridge,
    const scripting::MethodParameter& parameters) {
  std::string rules = GetParameterNamed("rules", parameters);
  if (rules.length()) {
    life_simulation_.SetAutomatonRules(rules);
  }
}

void LifeApplication::RunSimulation(
    const scripting::ScriptingBridge& bridge,
    const scripting::MethodParameter& parameters) {
  std::string sim_mode = GetParameterNamed("mode", parameters);
  if (sim_mode.length() == 0) {
    return;
  }
  if (sim_mode == kRandomSeedModeId) {
    life_simulation_.set_simulation_mode(life::Life::kRunRandomSeed);
  } else {
    life_simulation_.set_simulation_mode(life::Life::kRunStamp);
  }
  // Schedule a simulation tick to get things going.
  pp::Module::Get()->core()->CallOnMainThread(
      kSimulationTickInterval,
      pp::CompletionCallback(&SimulationTickCallback, this),
      PP_OK);
}

void LifeApplication::StopSimulation(
    const scripting::ScriptingBridge& bridge,
    const scripting::MethodParameter& parameters) {
  // This will pause the simulation on the next tick.
  life_simulation_.set_simulation_mode(life::Life::kPaused);
}

void LifeApplication::PutStampAtPoint(
    const scripting::ScriptingBridge& bridge,
    const scripting::MethodParameter& parameters) {
  std::string x_coord = GetParameterNamed("x", parameters);
  std::string y_coord = GetParameterNamed("y", parameters);
  if (x_coord.length() == 0 || y_coord.length() == 0) {
    return;
  }
  int32_t x = StringAsInt32(x_coord);
  int32_t y = StringAsInt32(y_coord);
  life_simulation_.PutStampAtPoint(stamp_, pp::Point(x, y));
  // If the simulation isn't running, make sure the stamp shows up.
  if (!is_running())
    Update();
}

void LifeApplication::CreateContext(const pp::Size& size) {
  if (IsContextValid())
    return;
  graphics_2d_context_ = new pp::Graphics2D(this, size, false);
  if (!BindGraphics(*graphics_2d_context_)) {
    printf("Couldn't bind the device context\n");
  }
}

void LifeApplication::DestroyContext() {
  if (!IsContextValid())
    return;
  shared_pixel_buffer_.reset();
  life_simulation_.set_pixel_buffer(shared_pixel_buffer_);
  delete graphics_2d_context_;
  graphics_2d_context_ = NULL;
}

void LifeApplication::FlushPixelBuffer() {
  if (!IsContextValid() || shared_pixel_buffer_ == NULL)
    return;
  set_flush_pending(true);
  graphics_2d_context_->PaintImageData(*(shared_pixel_buffer_.get()),
                                       pp::Point());
  graphics_2d_context_->Flush(pp::CompletionCallback(&FlushCallback, this));
}

const char* const LifeApplication::PostMessageBridge::kPostMessageMethodId =
    "postMessage";

bool LifeApplication::PostMessageBridge::HasMethod(const pp::Var& method,
                                                   pp::Var* exception) {
  if (!method.is_string()) {
    SetExceptionString(exception, kExceptionMethodNotAString);
    return false;
  }
  return method.AsString() == kPostMessageMethodId;
}

pp::Var LifeApplication::PostMessageBridge::Call(
    const pp::Var& method,
    const std::vector<pp::Var>& args,
    pp::Var* exception) {
  if (!method.is_string()) {
    SetExceptionString(exception, kExceptionMethodNotAString);
    return pp::Var();
  }
  if (method.AsString() != kPostMessageMethodId) {
    SetExceptionString(
        exception, std::string(kExceptionNoMethodName) + method.AsString());
    return pp::Var();
  }
  if (args.size() < 1) {
    SetExceptionString(
        exception, std::string(kInsufficientArgs) + method.AsString());
    return pp::Var();
  }
  if (!args[0].is_string()) {
    SetExceptionString(exception,
                       std::string(kInvalidArgs) + method.AsString());
    return pp::Var();
  }
  app_instance_->HandleMessage(args[0]);
  return pp::Var();
}
}  // namespace life

