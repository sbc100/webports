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
#include <string>

#include "experimental/life2011/life_stage_2/scoped_mutex_lock.h"
#include "experimental/life2011/life_stage_2/scoped_pixel_lock.h"

namespace {
const char* const kAddStampAtPointMethodId = "addStampAtPoint";
const char* const kClearMethodId = "clear";
const char* const kRunSimulationMethodId = "runSimulation";
const char* const kSetAutomatonRulesMethodId = "setAutomatonRules";
const char* const kStopSimulationMethodId = "stopSimulation";
const unsigned int kInitialRandSeed = 0xC0DE533D;
const int kSimulationTickInterval = 10;  // Measured in msec.

// Simulation modes.  These strings are matched by the browser script.
const char* const kRandomSeedModeId = "random_seed";
const char* const kStampModeId = "stamp";

// Exception strings.  These are passed back to the browser when errors
// happen during property accesses or method calls.
const char* const kExceptionMethodNotAString = "Method name is not a string";
const char* const kExceptionNoMethodName = "No method named ";
const char* const kInsufficientArgs =
    "Insufficient number of arguments to method ";

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

namespace life {
LifeApplication::LifeApplication(PP_Instance instance)
    : pp::Instance(instance),
      graphics_2d_context_(NULL),
      flush_pending_(false),
      view_changed_size_(true) {
  // Add the default stamp.
  stamps_.push_back(Stamp());
  current_stamp_index_ = 0;
}

LifeApplication::~LifeApplication() {
  life_simulation_.set_is_simulation_running(false);
  DestroyContext();
  stamps_.clear();
}

pp::Var LifeApplication::GetInstanceObject() {
  LifeScriptObject* script_object = new LifeScriptObject(this);
  return pp::Var(this, script_object);
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

void LifeApplication::Clear() {
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
}

void LifeApplication::SetAutomatonRules(const pp::Var& rule_string_var) {
  if (!rule_string_var.is_string())
    return;
  life_simulation_.SetAutomatonRules(rule_string_var.AsString());
}

void LifeApplication::RunSimulation(const pp::Var& simulation_mode) {
  if (!simulation_mode.is_string())
    return;
  if (simulation_mode.AsString() == kRandomSeedModeId) {
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

void LifeApplication::StopSimulation() {
  // This will pause the simulation on the next tick.
  life_simulation_.set_simulation_mode(life::Life::kPaused);
}

void LifeApplication::AddStampAtPoint(const pp::Var& var_x,
                                      const pp::Var& var_y) {
  if (!var_x.is_number() || !var_y.is_number() || current_stamp_index_ < 0)
    return;
  int32_t x, y;
  x = var_x.is_int() ? var_x.AsInt() : static_cast<int32_t>(var_x.AsDouble());
  y = var_y.is_int() ? var_y.AsInt() : static_cast<int32_t>(var_y.AsDouble());
  life_simulation_.AddStampAtPoint(stamps_[current_stamp_index_],
                                   pp::Point(x, y));
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

bool LifeApplication::LifeScriptObject::HasMethod(
    const pp::Var& method,
    pp::Var* exception) {
  if (!method.is_string()) {
    SetExceptionString(exception, kExceptionMethodNotAString);
    return false;
  }
  std::string method_name = method.AsString();
  return method_name == kAddStampAtPointMethodId ||
         method_name == kClearMethodId ||
         method_name == kRunSimulationMethodId ||
         method_name == kSetAutomatonRulesMethodId ||
         method_name == kStopSimulationMethodId;
}

pp::Var LifeApplication::LifeScriptObject::Call(
    const pp::Var& method,
    const std::vector<pp::Var>& args,
    pp::Var* exception) {
  if (!method.is_string()) {
    SetExceptionString(exception, kExceptionMethodNotAString);
    return pp::Var(false);
  }
  std::string method_name = method.AsString();
  if (app_instance_ != NULL) {
    if (method_name == kAddStampAtPointMethodId) {
      // Pull off the first two params.
      if (args.size() < 2) {
        SetExceptionString(exception,
                           std::string(kInsufficientArgs) + method_name);
        return pp::Var(false);
      }
      app_instance_->AddStampAtPoint(args[0], args[1]);
    } else if (method_name == kClearMethodId) {
      app_instance_->Clear();
    } else if (method_name == kRunSimulationMethodId) {
      // runSimulation() requires at least one arg.
      if (args.size() < 1) {
        SetExceptionString(exception,
                           std::string(kInsufficientArgs) + method_name);
        return pp::Var(false);
      }
      app_instance_->RunSimulation(args[0]);
    } else if (method_name == kSetAutomatonRulesMethodId) {
      // setSutomatonRules() requires at least one arg.
      if (args.size() < 1) {
        SetExceptionString(exception,
                           std::string(kInsufficientArgs) + method_name);
        return pp::Var(false);
      }
      app_instance_->SetAutomatonRules(args[0]);
    } else if (method_name == kStopSimulationMethodId) {
      app_instance_->StopSimulation();
    } else {
      SetExceptionString(exception,
                         std::string(kExceptionNoMethodName) + method_name);
    }
  }
  return pp::Var(true);
}
}  // namespace life

