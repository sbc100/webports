// Copyright 2011 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "experimental/life2011/life_stage_3/life_application.h"

#include <ppapi/c/pp_errors.h>
#include <ppapi/cpp/completion_callback.h>
#include <ppapi/cpp/var.h>

#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <string>

#include "experimental/life2011/life_stage_3/scoped_pixel_lock.h"
#include "experimental/life2011/life_stage_3/threading/scoped_mutex_lock.h"

namespace {
const char* const kClearMethodId = "clear";
const char* const kPutStampAtPointMethodId = "putStampAtPoint";
const char* const kRunSimulationMethodId = "runSimulation";
const char* const kSetAutomatonRulesMethodId = "setAutomatonRules";
const char* const kSetCurrentStampMethodId = "setCurrentStamp";
const char* const kStopSimulationMethodId = "stopSimulation";

const unsigned int kInitialRandSeed = 0xC0DE533D;
const int kSimulationTickInterval = 10;  // Measured in msec.

// Simulation modes.  These strings are matched by the browser script.
const char* const kRandomSeedModeId = "random_seed";
const char* const kStampModeId = "stamp";

// Exception strings.  These are passed back to the browser when errors
// happen during property accesses or method calls.
const char* const kInsufficientArgs =
    "Insufficient number of arguments to method ";
const char* const kInvalidArgs = "Invalid arguments to method ";
const char* const kInvalidStampFormat = "Invalid stamp format: ";

// Helper function to set the scripting exception.  Both |exception| and
// |except_string| can be NULL.  If |exception| is NULL, this function does
// nothing.
void SetExceptionString(pp::Var* exception, const std::string& except_string) {
  if (exception) {
    *exception = except_string;
  }
}

inline uint32_t MakeRGBA(uint32_t r, uint32_t g, uint32_t b, uint32_t a) {
  return (((a) << 24) | ((r) << 16) | ((g) << 8) | (b));
}

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
  life_simulation_.set_is_simulation_running(false);
  DestroyContext();
}

pp::Var LifeApplication::GetInstanceObject() {
  ScriptingBridge* bridge = new ScriptingBridge();
  if (bridge == NULL)
    return pp::Var();
  // Add all the methods to the scripting bridge.
  ScriptingBridge::SharedMethodCallbackExecutor
      clear_method(new scripting::MethodCallback<LifeApplication>(
          this, &LifeApplication::Clear));
  bridge->AddMethodNamed(kClearMethodId, clear_method);

  ScriptingBridge::SharedMethodCallbackExecutor
      put_stamp_method(new scripting::MethodCallback<LifeApplication>(
          this, &LifeApplication::PutStampAtPoint));
  bridge->AddMethodNamed(kPutStampAtPointMethodId, put_stamp_method);

  ScriptingBridge::SharedMethodCallbackExecutor
      run_sim_method(new scripting::MethodCallback<LifeApplication>(
          this, &LifeApplication::RunSimulation));
  bridge->AddMethodNamed(kRunSimulationMethodId, run_sim_method);

  ScriptingBridge::SharedMethodCallbackExecutor
      set_auto_rules_method(new scripting::MethodCallback<LifeApplication>(
          this, &LifeApplication::SetAutomatonRules));
  bridge->AddMethodNamed(kSetAutomatonRulesMethodId, set_auto_rules_method);

  ScriptingBridge::SharedMethodCallbackExecutor
      set_stamp_method(new scripting::MethodCallback<LifeApplication>(
          this, &LifeApplication::SetCurrentStamp));
  bridge->AddMethodNamed(kSetCurrentStampMethodId, set_stamp_method);

  ScriptingBridge::SharedMethodCallbackExecutor
      stop_sim_method(new scripting::MethodCallback<LifeApplication>(
          this, &LifeApplication::StopSimulation));
  bridge->AddMethodNamed(kStopSimulationMethodId, stop_sim_method);

  return pp::Var(this, bridge);
}

bool LifeApplication::Init(uint32_t /* argc */,
                           const char* /* argn */[],
                           const char* /* argv */[]) {
  life_simulation_.StartSimulation();
  return true;
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
    threading::ScopedMutexLock scoped_mutex(
        life_simulation_.simulation_mutex());
    if (!scoped_mutex.is_valid())
      return;
    life_simulation_.DeleteCells();
    if (graphics_2d_context_ != NULL) {
      shared_pixel_buffer_.reset(
          new LockingImageData(this,
                               PP_IMAGEDATAFORMAT_BGRA_PREMUL,
                               graphics_2d_context_->size(),
                               false));
      set_flush_pending(false);
      uint32_t* pixels = shared_pixel_buffer_->PixelBufferNoLock();
      if (pixels) {
        const size_t size = width() * height();
        std::fill(pixels, pixels + size, MakeRGBA(0, 0, 0, 0xff));
      }
      life_simulation_.Resize(width(), height());
      life_simulation_.set_pixel_buffer(shared_pixel_buffer_);
    }
    view_changed_size_ = false;
  }
  FlushPixelBuffer();
}

pp::Var LifeApplication::SetCurrentStamp(const ScriptingBridge& bridge,
                                         const std::vector<pp::Var>& args,
                                         pp::Var* exception) {
  // Require one string parameter.
  if (args.size() < 1) {
    SetExceptionString(
        exception, std::string(kInsufficientArgs) + kSetCurrentStampMethodId);
    return pp::Var(false);
  }
  if (!args[0].is_string()) {
    SetExceptionString(exception,
                       std::string(kInvalidArgs) + kSetCurrentStampMethodId);
    return pp::Var(false);
  }
  if (!stamp_.InitFromDescription(args[0].AsString())) {
    SetExceptionString(exception,
                       std::string(kInvalidStampFormat) + args[0].AsString());
    return pp::Var(false);
  }
  return pp::Var(true);
}

pp::Var LifeApplication::Clear(const ScriptingBridge& bridge,
                               const std::vector<pp::Var>& args,
                               pp::Var* exception) {
  // Temporarily pause the the simulation while clearing the buffers.
  volatile Life::SimulationMode sim_mode = life_simulation_.simulation_mode();
  if (sim_mode != Life::kPaused)
    life_simulation_.set_simulation_mode(Life::kPaused);
  life_simulation_.ClearCells();
  ScopedPixelLock scoped_pixel_lock(shared_pixel_buffer_.get());
  uint32_t* pixel_buffer = scoped_pixel_lock.pixels();
  if (pixel_buffer) {
    const size_t size = width() * height();
    std::fill(pixel_buffer,
              pixel_buffer + size,
              MakeRGBA(0, 0, 0, 0xff));
  }
  Update();  // Flushes the buffer correctly.
  if (sim_mode != Life::kPaused)
    life_simulation_.set_simulation_mode(sim_mode);
  return pp::Var(true);
}

pp::Var LifeApplication::SetAutomatonRules(const ScriptingBridge& bridge,
                                           const std::vector<pp::Var>& args,
                                           pp::Var* exception) {
  // setAutomatonRules() requires at least one arg.
  if (args.size() < 1) {
    SetExceptionString(
        exception, std::string(kInsufficientArgs) + kSetAutomatonRulesMethodId);
    return pp::Var(false);
  }
  if (!args[0].is_string()) {
    SetExceptionString(exception,
                       std::string(kInvalidArgs) + kSetAutomatonRulesMethodId);
    return pp::Var(false);
  }
  life_simulation_.SetAutomatonRules(args[0].AsString());
  return pp::Var(true);
}

pp::Var LifeApplication::RunSimulation(const ScriptingBridge& bridge,
                                       const std::vector<pp::Var>& args,
                                       pp::Var* exception) {
  // runSimulation() requires at least one arg.
  if (args.size() < 1) {
    SetExceptionString(exception,
                       std::string(kInsufficientArgs) + kRunSimulationMethodId);
    return pp::Var(false);
  }
  if (!args[0].is_string()) {
    SetExceptionString(exception,
                       std::string(kInvalidArgs) + kRunSimulationMethodId);
    return pp::Var(false);
  }
  if (args[0].AsString() == kRandomSeedModeId) {
    life_simulation_.set_simulation_mode(life::Life::kRunRandomSeed);
  } else {
    life_simulation_.set_simulation_mode(life::Life::kRunStamp);
  }
  // Schedule a simulation tick to get things going.
  pp::Module::Get()->core()->CallOnMainThread(
      kSimulationTickInterval,
      pp::CompletionCallback(&SimulationTickCallback, this),
      PP_OK);
  return pp::Var(true);
}

pp::Var LifeApplication::StopSimulation(const ScriptingBridge& bridge,
                                        const std::vector<pp::Var>& args,
                                        pp::Var* exception) {
  // This will pause the simulation on the next tick.
  life_simulation_.set_simulation_mode(life::Life::kPaused);
  return pp::Var(true);
}

pp::Var LifeApplication::PutStampAtPoint(const ScriptingBridge& bridge,
                                         const std::vector<pp::Var>& args,
                                         pp::Var* exception) {
  // Pull off the first two params.
  if (args.size() < 2) {
    SetExceptionString(
        exception, std::string(kInsufficientArgs) + kPutStampAtPointMethodId);
    return pp::Var(false);
  }
  if (!args[0].is_number() ||
      !args[1].is_number()) {
    SetExceptionString(exception,
                       std::string(kInvalidArgs) + kPutStampAtPointMethodId);
    return pp::Var(false);
  }
  int32_t x, y;
  x = args[0].is_int() ? args[0].AsInt() :
                         static_cast<int32_t>(args[0].AsDouble());
  y = args[1].is_int() ? args[1].AsInt() :
                         static_cast<int32_t>(args[1].AsDouble());
  life_simulation_.PutStampAtPoint(stamp_, pp::Point(x, y));
  // If the simulation isn't running, make sure the stamp shows up.
  if (!is_running())
    Update();
  return pp::Var(true);
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
  threading::ScopedMutexLock scoped_mutex(life_simulation_.simulation_mutex());
  if (!scoped_mutex.is_valid()) {
    return;
  }
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
}  // namespace life

