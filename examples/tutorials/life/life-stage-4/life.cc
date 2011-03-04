// Copyright 2011 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "examples/tutorials/life/life-stage-4/life.h"

#include <ppapi/c/pp_errors.h>
#include <ppapi/c/pp_input_event.h>
#include <ppapi/cpp/completion_callback.h>
#include <ppapi/cpp/var.h>

#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <string>

extern "C" {
// These files are installed into the NaCl toolchain by the $(LIB_JPEG) target
// in the Makefile.  Note that these files have dependencies on stdio.h and
// must be included in this order.  The linter doesn't like this.
#include <jerror.h>  // NOLINT
#include <jpeglib.h>  // NOLINT
}

#include "examples/tutorials/life/life-stage-4/geturl_handler.h"
#include "examples/tutorials/life/life-stage-4/scoped_mutex_lock.h"
#include "examples/tutorials/life/life-stage-4/scoped_pixel_lock.h"

// Helper function to read JPEG data from a memory buffer instead of requiring
// a file descriptor.  See jpg_mem_src.cc for mroe details.
void jpeg_mem_src(j_decompress_ptr cinfo,
                  uint8_t* inbuffer,
                  size_t insize);

namespace {
const char* const kUpdateMethodId = "update";
const char* const kAddCellAtPointMethodId = "addCellAtPoint";
const char* const kImageUrlPropertyId = "imageUrl";
const unsigned int kInitialRandSeed = 0xC0DE533D;
const int kRGBBytesPerPixel = 3;
// Exception strings.  These are passed back to the browser when errors
// happen during property accesses or method calls.
const char* const kExceptionMethodNotAString = "Method name is not a string";
const char* const kExceptionNoMethodName = "No method named ";
const char* const kExceptionPropertyNotAString =
    "Property name is not a string";
const char* const kExceptionNoPropertyName = "No property named ";
const char* const kExceptionNotAString = "Expected a string value for ";
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

void FlushCallback(void* data, int32_t result) {
  static_cast<life::Life*>(data)->set_flush_pending(false);
}
}  // namespace

namespace life {
Life::Life(PP_Instance instance) : pp::Instance(instance),
                                   life_simulation_thread_(NULL),
                                   is_running_(false),
                                   graphics_2d_context_(NULL),
                                   pixel_buffer_(NULL),
                                   flush_pending_(false),
                                   view_changed_size_(false),
                                   is_mouse_down_(false),
                                   random_bits_(kInitialRandSeed),
                                   cell_in_(NULL),
                                   cell_out_(NULL) {
  pthread_mutex_init(&pixel_buffer_mutex_, NULL);
}

Life::~Life() {
  set_is_running(false);
  if (life_simulation_thread_) {
    pthread_join(life_simulation_thread_, NULL);
  }
  delete[] cell_in_;
  delete[] cell_out_;
  DestroyContext();
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
}

void Life::Update() {
  if (flush_pending())
    return;  // Don't attempt to flush if one is pending.
  if (view_changed_size_) {
    // Create a new device context with the new size.
    DestroyContext();
    CreateContext(view_size_);
    if (ResizeBuffers(view_size_)) {
      view_changed_size_ = false;
    }
  }
  FlushPixelBuffer();
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

void Life::AddCellAtPoint(const pp::Var& var_x, const pp::Var& var_y) {
  if (!var_x.is_number() || !var_y.is_number())
    return;
  int32_t x, y;
  x = var_x.is_int() ? var_x.AsInt() : static_cast<int32_t>(var_x.AsDouble());
  y = var_y.is_int() ? var_y.AsInt() : static_cast<int32_t>(var_y.AsDouble());
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

void Life::URLDidDownload(const std::vector<uint8_t>& data, int32_t error) {
  if (error != PP_OK)
    return;
  // Decompress the JPEG file into a background image buffer.
  struct jpeg_decompress_struct cinfo;
  struct jpeg_error_mgr jerr;
  cinfo.err = jpeg_std_error(&jerr);
  jpeg_create_decompress(&cinfo);
  jpeg_mem_src(&cinfo, const_cast<uint8_t*>(&data[0]), data.size());
  jpeg_read_header(&cinfo, TRUE);
  jpeg_start_decompress(&cinfo);
  boost::scoped_array<uint8_t>scanline_rgb(
      new uint8_t[cinfo.output_width * kRGBBytesPerPixel]);
  // Fill the background image buffer with the uncompressed data.
  background_image_size_ = pp::Size(cinfo.output_width, cinfo.output_height);
  background_image_.reset(
      new uint32_t[cinfo.output_width * cinfo.output_height]);
  uint32_t* dst = background_image_.get();
  for (uint32_t i = 0; i < cinfo.output_height; ++i) {
    uint8_t* src_scanline = scanline_rgb.get();
    jpeg_read_scanlines(&cinfo, &src_scanline, 1);
    // Copy the RGB scanline from the JPEG file to the ARGB Surface buffer.
    src_scanline = scanline_rgb.get();
    for (uint32_t j = 0; j < cinfo.output_width; ++j) {
      uint8_t r = src_scanline[0];
      uint8_t g = src_scanline[1];
      uint8_t b = src_scanline[2];
      src_scanline += kRGBBytesPerPixel;
      *dst++ = MakeRGBA(r, g, b, 0xFF);
    }
  }
}

void Life::Stir() {
  ScopedMutexLock scoped_mutex(&pixel_buffer_mutex_);
  if (!scoped_mutex.is_valid()) {
    return;
  }
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
  const uint32_t* background = background_image_.get();
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
      // "Composite" the background image with the new life cell.  Tile the
      // background image.
      if (background) {
        int src_x = x % background_image_size_.width();
        int src_y = y % background_image_size_.height();
        color |= *(background + src_y * background_image_size_.width() + src_x);
      }
      *scanline++ = color;
      *dst++ = kIsAlive[count];
      ++src0;
      ++src1;
      ++src2;
    }
  }
}

void Life::Swap() {
  ScopedMutexLock scoped_mutex(&pixel_buffer_mutex_);
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
  // is_running() return |false|.
  life->set_is_running(true);
  while (life->is_running()) {
    life->Stir();
    life->UpdateCells();
    life->Swap();
  }
  return NULL;
}

void Life::CreateContext(const pp::Size& size) {
  ScopedMutexLock scoped_mutex(&pixel_buffer_mutex_);
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
  ScopedMutexLock scoped_mutex(&pixel_buffer_mutex_);
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

bool Life::ResizeBuffers(const pp::Size& size) {
  ScopedMutexLock scoped_mutex(&pixel_buffer_mutex_);
  if (!scoped_mutex.is_valid())
    return false;
  delete[] cell_in_;
  delete[] cell_out_;
  cell_in_ = cell_out_ = NULL;
  if (IsContextValid()) {
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
  return true;
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
  return method_name == kUpdateMethodId ||
         method_name == kAddCellAtPointMethodId;
}

bool Life::LifeScriptObject::HasProperty(const pp::Var& name,
                                         pp::Var* exception) {
  if (!name.is_string()) {
    SetExceptionString(exception, kExceptionPropertyNotAString);
    return false;
  }
  return name.AsString() == kImageUrlPropertyId;
}

pp::Var Life::LifeScriptObject::GetProperty(const pp::Var& name,
                                            pp::Var* exception) {
  if (!name.is_string()) {
    SetExceptionString(exception, kExceptionPropertyNotAString);
    return pp::Var();
  }
  if (name.AsString() == kImageUrlPropertyId) {
    return pp::Var(app_instance_->image_url());
  }
  SetExceptionString(exception,
                     std::string(kExceptionNoPropertyName) + name.AsString());
  return pp::Var();
}

void Life::LifeScriptObject::SetProperty(const pp::Var& name,
                                         const pp::Var& value,
                                         pp::Var* exception) {
  if (!name.is_string()) {
    SetExceptionString(exception, kExceptionPropertyNotAString);
    return;
  }
  if (name.AsString() == kImageUrlPropertyId) {
    if (!value.is_string()) {
      SetExceptionString(exception,
          std::string(kExceptionNotAString) + kImageUrlPropertyId);
      return;
    }
    // Setting the |imageUrl| property ha the side-effect of downloading a
    // new backround image.
    app_instance_->set_image_url(value.AsString());
    // Starts asynchronous download. When download is finished or when an
    // error occurs, |handler| calls JavaScript function
    // reportResult(url, result, success) (defined in geturl.html) and
    // self-destroys.
    GetURLHandler* handler = GetURLHandler::Create(app_instance_,
                                                   app_instance_->image_url());
    if (handler != NULL) {
      GetURLHandler::SharedURLCallbackExecutor url_callback(
          new GetURLHandler::URLCallback<Life>(app_instance_,
                                               &life::Life::URLDidDownload));
      handler->Start(url_callback);
    }
  } else {
    SetExceptionString(exception,
                       std::string(kExceptionNoPropertyName) + name.AsString());
  }
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
    if (method_name == kUpdateMethodId) {
      app_instance_->Update();
    } else if (method_name == kAddCellAtPointMethodId) {
      // Pull off the first two params.
      if (args.size() < 2) {
        SetExceptionString(exception,
                           std::string(kInsufficientArgs) + method_name);
        return pp::Var(false);
      }
      app_instance_->AddCellAtPoint(args[0], args[1]);
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

