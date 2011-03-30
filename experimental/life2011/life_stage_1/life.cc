// Copyright 2011 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "examples/tutorials/life/life-stage-1/life.h"

#include <ppapi/c/pp_errors.h>
#include <ppapi/cpp/completion_callback.h>
#include <ppapi/cpp/var.h>

#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <string>

namespace {
const unsigned int kInitialRandSeed = 0xC0DE533D;
const int kSimulationTickInterval = 10;  // Measured in msec.

// Exception strings.  These are passed back to the browser when errors
// happen during property accesses or method calls.
const char* const kExceptionMethodNotAString = "Method name is not a string";
const char* const kExceptionNoMethodName = "No method named ";

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
  static_cast<life::Life*>(data)->Update();
  pp::Module::Get()->core()->CallOnMainThread(
      kSimulationTickInterval,
      pp::CompletionCallback(&SimulationTickCallback, data),
      PP_OK);
}

// Called from the browser when the 2D graphics have been flushed out to the
// device.
void FlushCallback(void* data, int32_t result) {
  static_cast<life::Life*>(data)->set_flush_pending(false);
}
}  // namespace

namespace life {
Life::Life(PP_Instance instance) : pp::Instance(instance),
                                   graphics_2d_context_(NULL),
                                   pixel_buffer_(NULL),
                                   random_bits_(kInitialRandSeed),
                                   flush_pending_(false),
                                   cell_in_(NULL),
                                   cell_out_(NULL) {
}

Life::~Life() {
  delete[] cell_in_;
  delete[] cell_out_;
  DestroyContext();
  delete pixel_buffer_;
}

bool Life::Init(uint32_t /* argc */,
                const char* /* argn */[],
                const char* /* argv */[]) {
  // Schedule the first simulation tick.
  pp::Module::Get()->core()->CallOnMainThread(
      kSimulationTickInterval,
      pp::CompletionCallback(&SimulationTickCallback, this),
      PP_OK);
  return true;
}

void Life::Plot(int x, int y) {
  if (cell_in_ == NULL ||
      x < 0 ||
      x >= width() ||
      y < 0 ||
      y >= height()) {
    return;
  }
  *(cell_in_ + x + y * width()) = 1;
}

void Life::DidChangeView(const pp::Rect& position,
                         const pp::Rect& /* clip */) {
  if (position.size().width() == width() &&
      position.size().height() == height())
    return;  // Size didn't change, no need to update anything.

  // Create a new device context with the new size.
  DestroyContext();
  CreateContext(position.size());
  // Delete the old pixel buffer and create a new one.
  delete pixel_buffer_;
  delete[] cell_in_;
  delete[] cell_out_;
  pixel_buffer_ = NULL;
  cell_in_ = cell_out_ = NULL;
  if (graphics_2d_context_ != NULL) {
    pixel_buffer_ = new pp::ImageData(this,
                                      PP_IMAGEDATAFORMAT_BGRA_PREMUL,
                                      graphics_2d_context_->size(),
                                      false);
    set_flush_pending(false);
    const size_t size = width() * height();
    cell_in_ = new uint8_t[size];
    cell_out_ = new uint8_t[size];
    std::fill(cell_in_, cell_in_ + size, 0);
    std::fill(cell_out_, cell_out_ + size, 0);
  }
}

void Life::Update() {
  Stir();
  UpdateCells();
  Swap();
  FlushPixelBuffer();
}

void Life::AddCellAtPoint(int x, int y) {
  Plot(x - 1, y - 1);
  Plot(x + 0, y - 1);
  Plot(x + 1, y - 1);
  Plot(x - 1, y + 0);
  Plot(x + 0, y + 0);
  Plot(x + 1, y + 0);
  Plot(x - 1, y + 1);
  Plot(x + 0, y + 1);
  Plot(x + 1, y + 1);
}

void Life::Stir() {
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

void Life::UpdateCells() {
  if (cell_in_ == NULL || cell_out_ == NULL || pixels() == NULL)
    return;
  const int sim_height = height();
  const int sim_width = width();
  // Do neighbor summation; apply rules, output pixel color.
  for (int y = 1; y < (sim_height - 1); ++y) {
    uint8_t *src0 = (cell_in_ + (y - 1) * sim_width) + 1;
    uint8_t *src1 = src0 + sim_width;
    uint8_t *src2 = src1 + sim_width;
    int count;
    uint32_t color;
    uint8_t *dst = (cell_out_ + (y) * sim_width) + 1;
    uint32_t *pixel_buffer = pixels() + y * sim_width;
    for (int x = 1; x < (sim_width - 1); ++x) {
      // Build sum, weight center by 9x.
      count = src0[-1] + src0[0] +     src0[1] +
              src1[-1] + src1[0] * 9 + src1[1] +
              src2[-1] + src2[0] +     src2[1];
      color = kNeighborColors[count];
      *pixel_buffer++ = color;
      *dst++ = kIsAlive[count];
      ++src0;
      ++src1;
      ++src2;
    }
  }
}

void Life::Swap() {
  std::swap(cell_in_, cell_out_);
}

void Life::CreateContext(const pp::Size& size) {
  if (IsContextValid())
    return;
  graphics_2d_context_ = new pp::Graphics2D(this, size, false);
  if (!BindGraphics(*graphics_2d_context_)) {
    printf("Couldn't bind the device context\n");
  }
}

void Life::DestroyContext() {
  if (!IsContextValid())
    return;
  delete graphics_2d_context_;
  graphics_2d_context_ = NULL;
}

void Life::FlushPixelBuffer() {
  if (!IsContextValid())
    return;
  graphics_2d_context_->PaintImageData(*pixel_buffer_, pp::Point());
  if (flush_pending())
    return;
  set_flush_pending(true);
  graphics_2d_context_->Flush(pp::CompletionCallback(&FlushCallback, this));
}

uint8_t Life::RandomBitGenerator::value() {
  return static_cast<uint8_t>(rand_r(&random_bit_seed_) & 1);
}

}  // namespace life

