// Copyright 2010 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "examples/graphics/photo_c_salt/photo.h"

#include <sys/time.h>
#include <sys/times.h>

#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "c_salt/scripting_bridge.h"
#include "examples/graphics/photo_c_salt/fastmath.h"
#include "examples/graphics/photo_c_salt/painter.h"
#include "examples/graphics/photo_c_salt/image.h"
#include "examples/graphics/photo_c_salt/image_manipulator.h"
#include "examples/graphics/photo_c_salt/image-inl.h"

namespace {
const int kDefaultBackgroundColor = c_salt::MakeARGB(0xD3, 0xD3, 0xD3, 255);
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

// Used for FPS calculation.
double GetTimeInSeconds();
}  // namespace

namespace photo {

Photo::Photo(NPP npp)
  : c_salt::Instance(npp),
    window_width_(0),
    window_height_(0),
    url_loader_(*this),
    frames_per_seconds_(0) {
  original_photo_.set_background_color(kDefaultBackgroundColor);
  scaled_photo_.set_background_color(kDefaultBackgroundColor);
}

Photo::~Photo() {
}

void Photo::InitializeMethods(c_salt::ScriptingBridge* bridge) {
  bridge->AddMethodNamed("loadImage", this, &Photo::LoadImageFromURL);
  bridge->AddMethodNamed("setValueForKey", this, &Photo::SetValueForKey);
  bridge->AddMethodNamed("getFPS", this, &Photo::GetFPS);
}

bool Photo::InstanceDidLoad(int width, int height) {
  graphics_context_.Init(*this);
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

  WindowDidChangeSize(width, height);
  return true;
}

void Photo::WindowDidChangeSize(int width, int height) {
  if ((window_width_ != width) || (window_height_ != height)) {
    window_width_ = width;
    window_height_ = height;
    OnImageDownloaded();
  }
}

bool Photo::SetValueForKey(std::string key, double value) {
  ParameterDictionary::iterator item = parameter_dictionary_.find(key);
  if (item == parameter_dictionary_.end())
    return false;  // Key is not in the dictionary.
  parameter_dictionary_[key] = value;

  double t1 = GetTimeInSeconds();
  ProcessPhoto();
  Paint();
  double t2 = GetTimeInSeconds();
  frames_per_seconds_ = 1. / (t2 - t1);
  return true;
}

int32_t Photo::GetFPS() {
  return frames_per_seconds_;
}

bool Photo::LoadImageFromURL(std::string url) {
  return url_loader_.Load(url);
}

void Photo::OnURLLoaded(const char* data, size_t data_sz) {
  original_photo_.InitWithData(data, data_sz);
  OnImageDownloaded();
}

void Photo::OnImageDownloaded() {
  frames_per_seconds_ = 0;
  c_salt::Rect src_rect(original_photo_.width(), original_photo_.height());
  c_salt::Rect dest_rect = src_rect;
  c_salt::Rect wnd_rect(window_width_, window_height_);
  wnd_rect.Deflate(kBorderSize);
  dest_rect.ShrinkToFit(wnd_rect);

  if ((src_rect.width() > dest_rect.width()) ||
      (src_rect.height() > dest_rect.height())) {
    double x_scale = static_cast<double>(dest_rect.width()) / src_rect.width();
    double y_scale =
        static_cast<double>(dest_rect.height()) / src_rect.height();
    double scale = std::min(x_scale, y_scale);
    c_salt::ImageManipulator manp(&scaled_photo_);
    manp.Scale(scale, scale, original_photo_);
  } else {
    scaled_photo_ = original_photo_;
  }
  ProcessPhoto();
  Paint();
}

void Photo::Paint() {
  if (!scaled_photo_.is_valid())
    return;

  c_salt::Rect src_rect(processed_photo_.width(), processed_photo_.height());
  c_salt::Rect dest_rect = src_rect;
  c_salt::Rect wnd_rect(window_width_, window_height_);
  wnd_rect.Deflate(kBorderSize);
  dest_rect.ShrinkToFit(wnd_rect);
  dest_rect.CenterIn(wnd_rect);

  c_salt::Painter painter(&graphics_context_);
  painter.DrawImage(dest_rect, processed_photo_, src_rect);
}

void Photo::ProcessPhoto() {
  if (!scaled_photo_.is_valid())
    return;
  float rotate_angle = parameter_dictionary_[kAngleKey] +
      (parameter_dictionary_[kFineAngleKey] / 100.0f);
  if (fabs(rotate_angle) >= 1) {
    c_salt::ImageManipulator manp(&processed_photo_);
    manp.Rotate(rotate_angle, scaled_photo_);
  } else {
    processed_photo_ = scaled_photo_;
  }
  ApplyColorTransform();
}

void Photo::ApplyColorTransform() {
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

  int sz = processed_photo_.width() * processed_photo_.height();
  uint32_t* processed_pixels = processed_photo_.PixelAddress(0, 0);

  for (int j = 0; j < sz; j++) {
    uint32_t color = processed_pixels[j];
    float r = c_salt::ExtractR(color) * k1Over255;
    float g = c_salt::ExtractG(color) * k1Over255;
    float b = c_salt::ExtractB(color) * k1Over255;
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
    dst_color = c_salt::MakeARGB(ir, ig, ib, 255);

    processed_pixels[j] = dst_color;
  }
}

}  // namespace photo

namespace c_salt {
Module* CreateModule() {
  return new photo::PhotoModule();
}
}  // namespace c_salt

namespace {
const double kMksInSec = 1000000.;
double GetTimeInSeconds() {
  struct timeval time_val;
  double res = 0;
  if (gettimeofday(&time_val, NULL) == 0)
    res =  time_val.tv_sec + (time_val.tv_usec / kMksInSec);
  return res;
}
}  // namespace

