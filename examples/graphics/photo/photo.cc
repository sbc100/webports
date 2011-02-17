// Copyright 2011 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "examples/graphics/photo/photo.h"

extern "C" {
// These files are installed into the NaCl toolchain by the $(LIB_JPEG) target
// in the Makefile.
#include <jpeglib.h>
#include <jerror.h>
}

#include <ppapi/c/pp_errors.h>
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "examples/graphics/photo/fastmath.h"
#include "examples/graphics/photo/geturl_handler.h"

// Helper function to read JPEG data from a memory buffer instead of requiring
// a file descriptor.  See jpg_mem_src.cc for mroe details.
void jpeg_mem_src(j_decompress_ptr cinfo,
                  uint8_t* inbuffer,
                  size_t insize);

// Anonymous namespace for the static consts.
namespace {
const int kDefaultBorderColor = MakeARGB(96, 96, 96, 255);
const int kBorderSize = 10;
const float k1Over255 = 1.0f / 255.0f;

// The keys for |parameter_dictionary_|.
const char* kAngleKey = "angle";
const char* kBlackPointKey = "blackPoint";
const char* kBrightnessKey = "brightness";
const char* kContrastKey = "contrast";
const char* kFillKey = "fill";
const char* kFineAngleKey = "fineAngle";
const char* kHighlightsHueKey = "highlightsHue";
const char* kHighlightsSaturationKey = "highlightsSaturation";
const char* kSaturationKey = "saturation";
const char* kShadowsHueKey = "shadowsHue";
const char* kShadowsSaturationKey = "shadowsSaturation";
const char* kSplitPointKey = "splitPoint";
const char* kTemperatureKey = "temperature";

// This is called by the brower when the 2D context has been flushed to the
// browser window.
void FlushCallback(void* data, int32_t result) {
  static_cast<photo::Photo*>(data)->set_flush_pending(false);
}
}  // namespace

namespace photo {

// Attempt to turn any NPVariant value into a float, except for NPObjects.
// NPStrings are passed into strtof() for conversion.
static float FloatValue(const pp::Var& variant) {
  float return_value = 0.0f;
  const PP_Var& pp_var = variant.pp_var();
  switch (pp_var.type) {
  case PP_VARTYPE_INT32:
    return_value = static_cast<float>(variant.AsInt());
    break;
  case PP_VARTYPE_DOUBLE:
    return_value = static_cast<float>(variant.AsDouble());
    break;
  case PP_VARTYPE_BOOL:
    return_value = variant.AsBool() ? 1.0f : 0.0f;
    break;
  case PP_VARTYPE_STRING:
    {
      std::string str_value(variant.AsString());
      return_value = str_value.empty() ? 0.0f :
                                         strtof(str_value.c_str(), NULL);
    }
    break;
  default:
    return_value = 0;
    break;
  }
  return return_value;
}

Photo::~Photo() {
  DestroyContext();
  delete pixel_buffer_;
}

pp::Var Photo::GetInstanceObject() {
  photo::ScriptingBridge* bridge = new photo::ScriptingBridge();
  if (bridge == NULL)
    return pp::Var();
  InitializeMethods(bridge);
  InitializeProperties(bridge);
  return pp::Var(this, bridge);
}

void Photo::InitializeMethods(ScriptingBridge* bridge) {
  ScriptingBridge::SharedMethodCallbackExecutor value_for_key_method(
      new photo::ConstMethodCallback<Photo>(this, &Photo::GetValueForKey));
  bridge->AddMethodNamed("valueForKey", value_for_key_method);
  ScriptingBridge::SharedMethodCallbackExecutor set_value_for_key_method(
      new photo::MethodCallback<Photo>(this, &Photo::SetValueForKey));
  bridge->AddMethodNamed("setValueForKey", set_value_for_key_method);
}

void Photo::InitializeProperties(ScriptingBridge* bridge) {
  ScriptingBridge::SharedPropertyAccessorCallbackExecutor get_image_url(
      new photo::PropertyAccessorCallback<Photo>(this, &Photo::GetImageUrl));
  ScriptingBridge::SharedPropertyMutatorCallbackExecutor set_image_url(
      new photo::PropertyMutatorCallback<Photo>(this, &Photo::SetImageUrl));
  bridge->AddPropertyNamed("imageUrl", get_image_url, set_image_url);
}

pp::Var Photo::GetValueForKey(const ScriptingBridge& bridge,
                              const std::vector<pp::Var>& args) const {
  if (args.size() < 1 || !args[0].is_string()) {
    return false;
  }
  ParameterDictionary::const_iterator item =
      parameter_dictionary_.find(args[0].AsString());
  if (item == parameter_dictionary_.end()) {
    // Key is not in the dictionary.
    return pp::Var();
  }
  return pp::Var(static_cast<double>(item->second));
}

pp::Var Photo::SetValueForKey(const ScriptingBridge& bridge,
                              const std::vector<pp::Var>& args) {
  // |args[0]| is the value, and must be a simple type (int, double, string,
  // bool).  Objects are not evaluated.  |args[1]| is the key and must be a
  // string.
  if (args.size() < 2 || args[0].is_null() || !args[1].is_string()) {
    return pp::Var(false);
  }
  std::string key(args[1].AsString());
  ParameterDictionary::iterator item = parameter_dictionary_.find(key);
  if (item == parameter_dictionary_.end()) {
    // Key is not in the dictionary.
    return pp::Var(false);
  }
  parameter_dictionary_[key] = FloatValue(args[0]);
  FitPhotoToWorking();
  ApplyWorkingToFinal(working_photo_.get(), final_photo_.get());
  Paint();
  return pp::Var(true);
}

pp::Var Photo::GetImageUrl(const ScriptingBridge& bridge) const {
  return pp::Var(image_url_);
}

bool Photo::SetImageUrl(const ScriptingBridge& bridge, const pp::Var& value) {
  if (!value.is_string()) {
    return false;
  }
  bool success = false;
  // Maintain a local copy the string contents of |value|.
  image_url_ = value.AsString();
  // Starts asynchronous download. When download is finished or when an
  // error occurs, |handler| calls JavaScript function
  // reportResult(url, result, success) (defined in geturl.html) and
  // self-destroys.
  GetURLHandler* handler = GetURLHandler::Create(this, image_url_);
  if (handler != NULL) {
    GetURLHandler::SharedURLCallbackExecutor url_callback(
        new GetURLHandler::URLCallback<Photo>(this,
                                              &Photo::Photo::URLDidDownload));
    success = handler->Start(url_callback);
  }
  return success;
}

bool Photo::Init(uint32_t argc, const char* argn[], const char* argv[]) {
  // Allocate the Surface objects.  These will be made valid when
  // DidChangeView() is called.
  original_photo_.reset(new Surface());
  temp_photo_.reset(new Surface());
  working_photo_.reset(new Surface());
  rotated_photo_.reset(new Surface());
  final_photo_.reset(new Surface());

  // Populate the dictionary of photo editing values with some initial values.
  //    setting                    range
  // angle                 -45 .. 45
  // blackPoint            0 (identity) .. 100 (1 -> black)
  // brightness            0 (black) .. 100 (identity) .. 200
  // contrast              0 (crush) .. 100 (identity) .. 200
  // fill                  0 (identity) .. 100 (1 -> white)
  // fineAngle             -2 .. 2
  // highlightsHue         0 .. 1000 (normalized hue spectrum)
  // highlightsSaturation  0 (none) .. 100 (full)
  // saturation            0 (b&w) .. 100 (identity) .. 200 (over)
  // shadowsHue            0 .. 1000 (normalized hue spectrum)
  // shadowsSaturation     0 (none) .. 100 (full)
  // splitPoint            -100 (shadows) .. 0 (mid) .. 100 (highlights)
  // temperature           -2000 .. 2000
  parameter_dictionary_[kAngleKey] = 0.0f;
  parameter_dictionary_[kBlackPointKey] = 0.0f;
  parameter_dictionary_[kBrightnessKey] = 100.0f;
  parameter_dictionary_[kContrastKey] = 100.0f;
  parameter_dictionary_[kFillKey] = 0.0f;
  parameter_dictionary_[kFineAngleKey] = 0.0f;
  parameter_dictionary_[kHighlightsHueKey] = 0.0f;
  parameter_dictionary_[kHighlightsSaturationKey] = 0.0f;
  parameter_dictionary_[kSaturationKey] = 100.0f;
  parameter_dictionary_[kShadowsHueKey] = 0.0f;
  parameter_dictionary_[kShadowsSaturationKey] = 0.0f;
  parameter_dictionary_[kSplitPointKey] = 0.0f;
  parameter_dictionary_[kTemperatureKey] = 0.0f;
  return true;
}

void Photo::DidChangeView(const pp::Rect& position, const pp::Rect& clip) {
  if (position.size().width() == window_width_ &&
      position.size().height() == window_height_)
    return;  // Size didn't change, no need to update anything.

  // Create a new device context with the new size.
  DestroyContext();
  CreateContext(position.size());
  delete pixel_buffer_;
  pixel_buffer_ = NULL;
  if (IsContextValid()) {
    pixel_buffer_ = new pp::ImageData(this,
                                      PP_IMAGEDATAFORMAT_BGRA_PREMUL,
                                      graphics_2d_context_->size(),
                                      false);
  }

  window_width_ = position.size().width();
  window_height_ = position.size().height();
  // Reset all the photo surfaces in the pipeline to match the new module
  // window size, taking the border into account.
  int width_no_border = window_width_ - kBorderSize * 2;
  int height_no_border = window_height_ - kBorderSize * 2;
  original_photo_->SetWidthAndHeight(width_no_border, height_no_border, false);
  temp_photo_->SetWidthAndHeight(width_no_border, height_no_border, false);
  working_photo_->SetWidthAndHeight(width_no_border, height_no_border, false);
  rotated_photo_->SetWidthAndHeight(width_no_border, height_no_border, false);
  final_photo_->SetWidthAndHeight(width_no_border, height_no_border, false);
}

void Photo::URLDidDownload(const std::vector<uint8_t>& data, int32_t error) {
  if (error != PP_OK)
    return;
  // Read the JPEG file into the Surface object.
  struct jpeg_decompress_struct cinfo;
  struct jpeg_error_mgr jerr;
  cinfo.err = jpeg_std_error(&jerr);
  jpeg_create_decompress(&cinfo);
  jpeg_mem_src(&cinfo, const_cast<uint8_t*>(&data[0]), data.size());
  jpeg_read_header(&cinfo, TRUE);
  jpeg_start_decompress(&cinfo);

  original_photo_->SetWidthAndHeight(cinfo.output_width,
                                     cinfo.output_height,
                                     true);
  boost::scoped_array<uint8_t>scanline_rgb(
      new uint8_t[cinfo.output_width * 3]);
  for (uint32_t i = 0; i < cinfo.output_height; ++i) {
    uint8_t* src_scanline = scanline_rgb.get();
    jpeg_read_scanlines(&cinfo, &src_scanline, 1);
    // Copy the RGB scanline from the JPEG file to the ARGB Surface buffer.
    src_scanline = scanline_rgb.get();
    for (uint32_t j = 0; j < cinfo.output_width; ++j) {
      uint8_t r = src_scanline[0];
      uint8_t g = src_scanline[1];
      uint8_t b = src_scanline[2];
      src_scanline += 3;
      original_photo_->PutPixelNoClip(j, i, MakeARGB(r, g, b, 0xFF));
    }
  }
  FitPhotoToWorking();
  ApplyWorkingToFinal(working_photo_.get(), final_photo_.get());
  Paint();
}

bool Photo::Paint() {
  if (!IsContextValid())
    return false;
  if (pixel_buffer_ == NULL || pixel_buffer_->is_null())
    return false;
  uint32_t* window_pixels = static_cast<uint32_t*>(pixel_buffer_->data());
  const uint32_t* photo_pixels = final_photo_->pixels();
  // Center the photo in the browser window, inset by the border size.
  int width_no_border = window_width_ - kBorderSize * 2;
  int height_no_border = window_height_ - kBorderSize * 2;
  int clip_width = std::min(width_no_border, final_photo_->width());
  int clip_height = std::min(height_no_border, final_photo_->height());
  int clip_origin_x = 0;
  int clip_origin_y = 0;
  if (clip_width < width_no_border) {
    clip_origin_x = (width_no_border - clip_width) / 2;
  }
  if (clip_height < height_no_border) {
    clip_origin_y = (height_no_border - clip_height) / 2;
  }
  clip_origin_x += kBorderSize;
  clip_origin_y += kBorderSize;
  window_pixels += clip_origin_x + clip_origin_y * window_width_;
  for (int y = 0; y < clip_height; ++y) {
    memcpy(window_pixels, photo_pixels, clip_width * sizeof(uint32_t));
    window_pixels += window_width_;
    photo_pixels += final_photo_->width();
  }
  graphics_2d_context_->PaintImageData(*pixel_buffer_, pp::Point());
  if (!flush_pending()) {
    set_flush_pending(true);
    graphics_2d_context_->Flush(pp::CompletionCallback(&FlushCallback, this));
  }
  return true;
}

void Photo::CreateContext(const pp::Size& size) {
  if (IsContextValid()) {
    return;
  }
  graphics_2d_context_ = new pp::Graphics2D(this, size, false);
  if (!BindGraphics(*graphics_2d_context_)) {
    printf("Couldn't bind the device context\n");
  }
}

void Photo::DestroyContext() {
  if (!IsContextValid()) {
    return;
  }
  delete graphics_2d_context_;
  graphics_2d_context_ = NULL;
}

bool Photo::IsContextValid() {
  return graphics_2d_context_ != NULL;
}

void Photo::FitPhotoToWorking() {
  rotated_photo_->SetWidthAndHeight(original_photo_->width(),
                                    original_photo_->height(),
                                    false);
  float rotate_angle = parameter_dictionary_[kAngleKey] +
                       parameter_dictionary_[kFineAngleKey] / 100.0f;
  RotatePhoto(original_photo_.get(), rotated_photo_.get(), rotate_angle);
  // Convert photo -> working photo.  The working photo does not include
  // the border pixels.
  int width_no_border = window_width_ - kBorderSize * 2;
  int height_no_border = window_height_ - kBorderSize * 2;
  if ((rotated_photo_->width() <= width_no_border) &&
      (rotated_photo_->height() <= height_no_border)) {
    // The original photo is smaller than working surface, so copy 1:1
    working_photo_->SetWidthAndHeight(rotated_photo_->width(),
                                      rotated_photo_->height(),
                                      false);
    working_photo_->Copy(0, 0, rotated_photo_.get());
  } else {
    // The original photo is larger than working surface, so it needs to be
    // scaled down such that its longest dimension fits in the module's window.
    float scale;
    if (rotated_photo_->width() > rotated_photo_->height()) {
      scale = static_cast<float>(width_no_border) /
              static_cast<float>(rotated_photo_->width());
    } else {
      scale = static_cast<float>(height_no_border) /
              static_cast<float>(rotated_photo_->height());
    }
    if (rotated_photo_->width() * scale > width_no_border) {
      scale *= width_no_border / (rotated_photo_->width() * scale);
    }
    if (rotated_photo_->height() * scale > height_no_border) {
      scale *= height_no_border / (rotated_photo_->height() * scale);
    }
    working_photo_->RescaleFrom(rotated_photo_.get(),
                                scale,
                                scale,
                                temp_photo_.get());
  }
}

void Photo::RotatePhoto(const Surface* photo,
                        Surface* rotated_photo,
                        float angle) {
  rotated_photo->Clear(kDefaultBorderColor);
  temp_photo_->set_border_color(kDefaultBorderColor);
  rotated_photo->Rotate(angle, photo, temp_photo_.get());
}

void Photo::ApplyWorkingToFinal(const Surface* working_photo,
                                Surface* final_photo) {
  // Grab a snapshot into local vars of current settings, scaling the input
  // values as needed.
  float black_point = parameter_dictionary_[kBlackPointKey] / 100.0f;
  float brightness = parameter_dictionary_[kBrightnessKey] / 100.0f;
  float contrast = parameter_dictionary_[kContrastKey] / 100.0f;
  float fill = parameter_dictionary_[kFillKey] / 100.0f;
  float highlights_hue = parameter_dictionary_[kHighlightsHueKey] / 1000.0f;
  float highlights_saturation =
      parameter_dictionary_[kHighlightsSaturationKey] / 100.0f;
  float saturation = parameter_dictionary_[kSaturationKey] / 100.0f;
  float shadows_hue = parameter_dictionary_[kShadowsHueKey] / 1000.0f;
  float shadows_saturation =
      parameter_dictionary_[kShadowsSaturationKey] / 100.0f;
  float split_point = parameter_dictionary_[kSplitPointKey] / 100.0f;
  float temperature = parameter_dictionary_[kTemperatureKey];

  fill *= 0.2f;
  float brightness_a;
  float brightness_b;
  brightness = (brightness - 1.0f) * 0.75f + 1.0f;
  if (brightness < 1.0f) {
    brightness_a = brightness;
    brightness_b = 0.0f;
  } else {
    brightness_b = brightness - 1.0f;
    brightness_a = 1.0f - brightness_b;
  }
  contrast = contrast * 0.5f;
  contrast = (contrast - 0.5f) * 0.75f + 0.5f;
  temperature = (temperature / 2000.0f) * 0.1f;
  if (temperature > 0.0f) temperature *= 2.0f;
  split_point = ((split_point + 1.0f) * 0.5f);

  final_photo->SetWidthAndHeight(working_photo->width(),
                                 working_photo->height(),
                                 false);
  int sz = final_photo->width() * final_photo->height();
  const uint32_t* working_pixels = working_photo->pixels();
  for (int j = 0; j < sz; j++) {
    uint32_t color = working_pixels[j];
    float r = ExtractR(color) * k1Over255;
    float g = ExtractG(color) * k1Over255;
    float b = ExtractB(color) * k1Over255;
    // convert RGB to YIQ
    // this is a less than ideal colorspace;
    // HSL would probably be better, but more expensive
    float y = 0.299f * r + 0.587f * g + 0.114f * b;
    float i = 0.596f * r - 0.275f * g - 0.321f * b;
    float q = 0.212f * r - 0.523f * g + 0.311f * b;
    i = i + temperature;
    q = q - temperature;
    i = i * saturation;
    q = q * saturation;
    y = (1.0f + black_point) * y - black_point;
    y = y + fill;
    y = y * brightness_a + brightness_b;
    y = FastGain(contrast, Clamp(y));
    if (y < split_point) {
      q = q + (shadows_hue * shadows_saturation) * (split_point - y);
    } else {
      i = i + (highlights_hue * highlights_saturation) * (y - split_point);
    }
    // convert back to RGB for display
    r = y + 0.956f * i + 0.621f * q;
    g = y - 0.272f * i - 0.647f * q;
    b = y - 1.105f * i + 1.702f * q;
    r = Clamp(r);
    g = Clamp(g);
    b = Clamp(b);
    int ir = std::floor(r * 255.0f);
    int ig = std::floor(g * 255.0f);
    int ib = std::floor(b * 255.0f);
    uint32_t dst_color;
    dst_color = MakeARGB(ir, ig, ib, 255);
    final_photo->PutPixelAt(j, dst_color);
  }
}

}  // namespace photo
