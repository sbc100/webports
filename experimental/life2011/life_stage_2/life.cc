// Copyright 2011 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "experimental/life2011/life_stage_2/life.h"

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

// Map of neighboring colors.
const uint32_t kNeighborColors[] = {
    MakeRGBA(0x00, 0x00, 0x00, 0xff),
    MakeRGBA(0x00, 0x40, 0x00, 0xff),
    MakeRGBA(0x00, 0x60, 0x00, 0xff),
    MakeRGBA(0x00, 0x80, 0x00, 0xff),
    MakeRGBA(0x00, 0xA0, 0x00, 0xff),
    MakeRGBA(0x00, 0xC0, 0x00, 0xff),
    MakeRGBA(0x00, 0xE0, 0x00, 0xff),
    MakeRGBA(0x00, 0x00, 0x00, 0xff),
    MakeRGBA(0x00, 0x40, 0x00, 0xff),
    MakeRGBA(0x00, 0x60, 0x00, 0xff),
    MakeRGBA(0x00, 0x80, 0x00, 0xff),
    MakeRGBA(0x00, 0xA0, 0x00, 0xff),
    MakeRGBA(0x00, 0xC0, 0x00, 0xff),
    MakeRGBA(0x00, 0xE0, 0x00, 0xff),
    MakeRGBA(0x00, 0xFF, 0x00, 0xff),
    MakeRGBA(0x00, 0xFF, 0x00, 0xff),
    MakeRGBA(0x00, 0xFF, 0x00, 0xff),
    MakeRGBA(0x00, 0xFF, 0x00, 0xff),
};

// These represent the new health value of a cell based on its neighboring
// values.  The health is binary: either alive or dead.
const uint8_t kIsAlive[] = {
      0, 0, 0, 1, 0, 0, 0, 0, 0,  // Values if the center cell is dead.
      0, 0, 1, 1, 0, 0, 0, 0, 0  // Values if the center cell is alive.
  };

// Called from the browser when the delay time has elapsed.  This routine
// runs a simulation update, then reschedules itself to run the next
// simulation tick.
void SimulationTickCallback(void* data, int32_t result) {
  life::Life* life_sim = static_cast<life::Life*>(data);
  life_sim->Update();
  if (life_sim->is_running()) {
    pp::Module::Get()->core()->CallOnMainThread(
        kSimulationTickInterval,
        pp::CompletionCallback(&SimulationTickCallback, data),
        PP_OK);
  }
}

// Called from the browser when the 2D graphics have been flushed out to the
// device.
void FlushCallback(void* data, int32_t result) {
  static_cast<life::Life*>(data)->set_flush_pending(false);
}
}  // namespace

namespace life {
Life::Life(PP_Instance instance) : pp::Instance(instance),
                                   life_simulation_thread_(NULL),
                                   sim_state_condition_(kStopped),
                                   graphics_2d_context_(NULL),
                                   pixel_buffer_(NULL),
                                   flush_pending_(false),
                                   view_changed_size_(true),
                                   play_mode_(kRandomSeedMode),
                                   is_running_(false),
                                   random_bits_(kInitialRandSeed),
                                   cell_in_(NULL),
                                   cell_out_(NULL) {
  pthread_mutex_init(&pixel_buffer_mutex_, NULL);
  // Add the default stamp.
  stamps_.push_back(Stamp());
  current_stamp_index_ = 0;
}

Life::~Life() {
  set_is_simulation_running(false);
  if (life_simulation_thread_) {
    pthread_join(life_simulation_thread_, NULL);
  }
  delete[] cell_in_;
  delete[] cell_out_;
  DestroyContext();
  stamps_.clear();
  pthread_mutex_destroy(&pixel_buffer_mutex_);
}

pp::Var Life::GetInstanceObject() {
  LifeScriptObject* script_object = new LifeScriptObject(this);
  return pp::Var(this, script_object);
}

bool Life::Init(uint32_t /* argc */,
                const char* /* argn */[],
                const char* /* argv */[]) {
  pthread_create(&life_simulation_thread_, NULL, LifeSimulation, this);
  return true;
}

void Life::DidChangeView(const pp::Rect& position,
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

void Life::Update() {
  if (flush_pending())
    return;  // Don't attempt to flush if one is pending.
  if (view_changed_size_) {
    // Create a new device context with the new size.
    DestroyContext();
    CreateContext(view_size_);
    // Delete the old pixel buffer and create a new one.
    threading::ScopedMutexLock scoped_mutex(&pixel_buffer_mutex_);
    if (!scoped_mutex.is_valid())
      return;
    delete[] cell_in_;
    delete[] cell_out_;
    cell_in_ = cell_out_ = NULL;
    if (graphics_2d_context_ != NULL) {
      pixel_buffer_ = new pp::ImageData(this,
                                        PP_IMAGEDATAFORMAT_BGRA_PREMUL,
                                        graphics_2d_context_->size(),
                                        false);
      set_flush_pending(false);
      const size_t size = width() * height();
      uint32_t* pixels = PixelBufferNoLock();
      if (pixels)
        std::fill(pixels, pixels + size, MakeRGBA(0, 0, 0, 0xff));
      cell_in_ = new uint8_t[size];
      cell_out_ = new uint8_t[size];
      ResetCells();
    }
    view_changed_size_ = false;
  }
  FlushPixelBuffer();
}

void Life::Clear() {
  ScopedPixelLock scoped_pixel_lock(this);
  uint32_t* pixel_buffer = scoped_pixel_lock.pixels();
  ResetCells();
  const size_t size = width() * height();
  if (pixel_buffer) {
    std::fill(pixel_buffer,
              pixel_buffer + size,
              MakeRGBA(0, 0, 0, 0xff));
  }
  Update();  // Flushes the buffer correctly.
}

void Life::SetAutomatonRules(const pp::Var& rule_string) {
  if (!rule_string.is_string())
    return;
  printf("New automaton rules: %s\n", rule_string.AsString().c_str());
}

void Life::RunSimulation(const pp::Var& simulation_mode) {
  if (!simulation_mode.is_string())
    return;
  if (simulation_mode.AsString() == kRandomSeedModeId) {
    play_mode_ = kRandomSeedMode;
  } else {
    play_mode_ = kStampMode;
  }
  // Schedule a simulation tick to get things going.
  set_is_running(true);
  pp::Module::Get()->core()->CallOnMainThread(
      kSimulationTickInterval,
      pp::CompletionCallback(&SimulationTickCallback, this),
      PP_OK);
}

void Life::StopSimulation() {
  // This will pause the simulation on the next tick.
  set_is_running(false);
}

void Life::AddRandomSeed() {
  threading::ScopedMutexLock scoped_mutex(&pixel_buffer_mutex_);
  if (!scoped_mutex.is_valid())
    return;
  if (cell_in_ == NULL || cell_out_ == NULL)
    return;
  const int sim_height = height();
  const int sim_width = width();
  for (int i = 0; i < sim_width; ++i) {
    cell_in_[i] = random_bits_.value();
    cell_in_[i + (sim_height - 1) * sim_width] = random_bits_.value();
  }
  for (int i = 0; i < sim_height; ++i) {
    cell_in_[i * sim_width] = random_bits_.value();
    cell_in_[i * sim_width + (sim_width - 1)] = random_bits_.value();
  }
}

void Life::AddStampAtPoint(const pp::Var& var_x, const pp::Var& var_y) {
  if (!var_x.is_number() || !var_y.is_number() || current_stamp_index_ < 0)
    return;
  int32_t x, y;
  x = var_x.is_int() ? var_x.AsInt() : static_cast<int32_t>(var_x.AsDouble());
  y = var_y.is_int() ? var_y.AsInt() : static_cast<int32_t>(var_y.AsDouble());
  // Note: do not acquire the pixel lock here, because stamping is done in the
  // UI thread.
  stamps_[current_stamp_index_].StampAtPointInBuffers(
      pp::Point(x, y),
      PixelBufferNoLock(),
      cell_in_,
      pp::Size(width(), height()));
  // If the simulation isn't running, make sure the stamp shows up.
  if (!is_running())
    Update();
}

void Life::UpdateCells() {
  ScopedPixelLock scoped_pixel_lock(this);
  uint32_t* pixel_buffer = scoped_pixel_lock.pixels();
  if (pixel_buffer == NULL || cell_in_ == NULL || cell_out_ == NULL) {
    // Note that if the pixel buffer never gets initialized, this won't ever
    // paint anything.  Which is probably the right thing to do.  Also, this
    // clause means that the image will not get the very first few sim cells,
    // since it's possible that this thread starts before the pixel buffer is
    // initialized.
    return;
  }
  const int sim_height = height();
  const int sim_width = width();
  // Do neighbor sumation; apply rules, output pixel color.
  for (int y = 1; y < (sim_height - 1); ++y) {
    uint8_t *src0 = (cell_in_ + (y - 1) * sim_width) + 1;
    uint8_t *src1 = src0 + sim_width;
    uint8_t *src2 = src1 + sim_width;
    int count;
    uint32_t color;
    uint8_t *dst = (cell_out_ + (y) * sim_width) + 1;
    uint32_t *scanline = pixel_buffer + y * sim_width;
    for (int x = 1; x < (sim_width - 1); ++x) {
      // Build sum, weight center by 9x.
      count = src0[-1] + src0[0] +     src0[1] +
              src1[-1] + src1[0] * 9 + src1[1] +
              src2[-1] + src2[0] +     src2[1];
      color = kNeighborColors[count];
      *scanline++ = color;
      *dst++ = kIsAlive[count];
      ++src0;
      ++src1;
      ++src2;
    }
  }
}

void Life::Swap() {
  threading::ScopedMutexLock scoped_mutex(&pixel_buffer_mutex_);
  if (!scoped_mutex.is_valid()) {
    return;
  }
  if (cell_in_ == NULL || cell_out_ == NULL) {
    return;
  }
  std::swap(cell_in_, cell_out_);
}

void* Life::LifeSimulation(void* param) {
  Life* life = static_cast<Life*>(param);
  // Run the Life simulation in an endless loop.  Shut this down when
  // is_simulation_running() returns |false|.
  life->set_is_simulation_running(true);
  while (life->is_simulation_running()) {
    if (life->is_running()) {
      if (life->play_mode() == Life::kRandomSeedMode)
        life->AddRandomSeed();
      life->UpdateCells();
      life->Swap();
    }
  }
  return NULL;
}

void Life::ResetCells() {
  const size_t size = width() * height();
  if (cell_in_)
    std::fill(cell_in_, cell_in_ + size, 0);
  if (cell_out_)
    std::fill(cell_out_, cell_out_ + size, 0);
}

void Life::CreateContext(const pp::Size& size) {
  threading::ScopedMutexLock scoped_mutex(&pixel_buffer_mutex_);
  if (!scoped_mutex.is_valid()) {
    return;
  }
  if (IsContextValid())
    return;
  graphics_2d_context_ = new pp::Graphics2D(this, size, false);
  if (!BindGraphics(*graphics_2d_context_)) {
    printf("Couldn't bind the device context\n");
  }
}

void Life::DestroyContext() {
  threading::ScopedMutexLock scoped_mutex(&pixel_buffer_mutex_);
  if (!scoped_mutex.is_valid()) {
    return;
  }
  if (!IsContextValid())
    return;
  delete pixel_buffer_;
  pixel_buffer_ = NULL;
  delete graphics_2d_context_;
  graphics_2d_context_ = NULL;
}

uint32_t* Life::PixelBufferNoLock() {
  if (pixel_buffer_ == NULL || pixel_buffer_->is_null())
    return NULL;
  return static_cast<uint32_t*>(pixel_buffer_->data());
}

void Life::FlushPixelBuffer() {
  if (!IsContextValid() || pixel_buffer_ == NULL)
    return;
  set_flush_pending(true);
  graphics_2d_context_->PaintImageData(*pixel_buffer_, pp::Point());
  graphics_2d_context_->Flush(pp::CompletionCallback(&FlushCallback, this));
}

bool Life::LifeScriptObject::HasMethod(
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

pp::Var Life::LifeScriptObject::Call(
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

uint8_t Life::RandomBitGenerator::value() {
  return static_cast<uint8_t>(rand_r(&random_bit_seed_) & 1);
}

}  // namespace life

