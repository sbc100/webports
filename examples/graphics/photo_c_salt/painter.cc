// Copyright 2010 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "examples/graphics/photo_c_salt/painter.h"
#include "examples/graphics/photo_c_salt/graphics_2d_context.h"
#include "examples/graphics/photo_c_salt/image.h"
#include "examples/graphics/photo_c_salt/image_manipulator.h"
#include "examples/graphics/photo_c_salt/image-inl.h"

namespace {
  uint32_t kDefaultBackgroundColor = c_salt::MakeARGB(0xD3, 0xD3, 0xD3, 255);
}

namespace c_salt {

Painter::Painter(Graphics2DContext* dc)
  : dc_(*dc),
  background_color_(kDefaultBackgroundColor) {
  Rect dc_r(dc_.GetSize());
  pixels_.Resize(dc_r.width(), dc_r.height());
  pixels_.set_background_color(background_color_);
  pixels_.Erase();
}

Painter::~Painter() {
  dc_.Update(pixels_);
}

void Painter::DrawImage(const Rect& destRect,
                        const Image& img,
                        const Rect& srcRect) {
  if ((destRect.width() == 0) || (destRect.height() == 0))
    return;
  if ((srcRect.width() == 0) || (srcRect.height() == 0))
    return;

  c_salt::ImageManipulator copy_manp(&pixels_);
  if ((destRect.width() != srcRect.width()) ||
      (destRect.height() != srcRect.height())) {
    // Scale source image.
    double x_scale = static_cast<double>(destRect.width()) / srcRect.width();
    double y_scale = static_cast<double>(destRect.height()) / srcRect.height();
    Image scaled_img;
    c_salt::ImageManipulator manp(&scaled_img);
    manp.Scale(x_scale, y_scale, img);

    copy_manp.Copy(destRect.left_, destRect.top_, scaled_img);
  } else {
    copy_manp.Copy(destRect.left_, destRect.top_, img);
  }
  // Pixels are send to device at the time of Painter destruction.
}
}  // namespace c_salt

