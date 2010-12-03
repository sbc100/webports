// Copyright 2010 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef EXAMPLES_GRAPHICS_PHOTO_C_SALT_PAINTER_H_
#define EXAMPLES_GRAPHICS_PHOTO_C_SALT_PAINTER_H_

#include "examples/graphics/photo_c_salt/image.h"
#include "examples/graphics/photo_c_salt/graphics_2d_context.h"
#include "examples/graphics/photo_c_salt/rect.h"

namespace c_salt {
// The Painter class performs painting on Graphics2DContext.
class Painter {
 public:
  // Create a Painter object assosiated with Graphics2DContext.
  explicit Painter(Graphics2DContext* dc);
  virtual ~Painter();

  // Draws the |srcRect| of the given |img| into the |destRect| in
  // the Graphics2DContext. The image is scaled to fit the rectangle.
  virtual void DrawImage(const Rect& destRect,
                         const Image& img,
                         const Rect& srcRect);

 private:
  Graphics2DContext& dc_;
  Image pixels_;
  uint32_t background_color_;
};
}  // namespace c_salt

#endif  // EXAMPLES_GRAPHICS_PHOTO_C_SALT_PAINTER_H_

