// Copyright 2010 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef EXAMPLES_GRAPHICS_PHOTO_C_SALT_IMAGE_MANIPULATOR_H_
#define EXAMPLES_GRAPHICS_PHOTO_C_SALT_IMAGE_MANIPULATOR_H_

#include "examples/graphics/photo_c_salt/image.h"

namespace c_salt {
class ImageManipulator {
 public:
  // Create ImageManipulator object and assosiate it with the target |img|
  // to work on. |img| shall exist for the life of ImageManipulator object.
  explicit ImageManipulator(Image* img) : target_img_(*img) {}
  virtual ~ImageManipulator() {}

  // Copy all of |src| into target Image, placing the copied image's
  // upper-left corner at pixel coordinates (|dst_x|, |dst_y|).  Clips |src|
  // to fit, clips all coordinates to lie within the target Image.
  void Copy(int dst_x, int dst_y, const Image& src);

  // Copy all of |src| into target Image, placing the copied image's
  // upper-left corner at pixel coordinates (|dst_x|, |dst_y|).  Scales |src|
  // such that it fits into target Image's dimensions.
  void Scale(float sx, float sy, const Image& src);

  // Copy the |src| Image into target one, applying a rotation by |degrees|.
  // |degrees| must be in range [-45 .. 45].  The rotation is done via 3
  // shearing operations.  This is slower than single pass, but easier to
  // implement with good filtering.
  void Rotate(float degrees, const Image& src);

 protected:
  // Copy the horizontal scanline from |src| to target  Image.  The scanline
  // is located at pixel coordinates (|src_x0|, |src_y|) and runs to location
  // (|src_x1|, |src_y|).  The scanline is copied to location (|dst_x|,
  // |dst_y|).  No coordinate clipping is performed.
  void CopyScanlineNoClip(int dst_x,
                          int dst_y,
                          int src_x0,
                          int src_x1,
                          int src_y,
                          const Image& src);

  // Copy the horizontal scanline from |src| to target Image.  The scanline
  // is located at pixel coordinates (|src_x0|, |src_y|) and runs to location
  // (|src_x1|, |src_y|).  The scanline is copied to location (|dst_x|,
  // |dst_y|). All coordinates are clipped to the respective Images before
  // copying.
  void CopyScanline(int dst_x,
                    int dst_y,
                    int src_x0,
                    int src_x1,
                    int src_y,
                    const Image& src);

  // Copy the horizontal scanline from |src| to target Image, applying a
  // scale such that all of the source pixels fit into the destination pixels.
  // |filter| indicates how wide of a box filter to use (typically 2 pixels).
  // The scanline is located at pixel coordinates (|src_x0|, |src_y|) and runs
  // to location (|src_x1|, |src_y|).  The scanline is copied (and scaled) to
  // location (|dst_x|, |dst_y|).  All coordinates are clipped to fit in their
  // respective Images.
  void ScaledCopyScanline(float dst_x0,
                          float dst_x1,
                          int dst_y,
                          float src_x0,
                          float src_x1,
                          int src_y,
                          const Image& src,
                          int filter);

  // Copy the vertical column from |src| to target Image, applying a scale
  // such that all of the source pixels fit into the destination pixels.
  // |filter| indicates how wide of a box filter to use (typically 2 pixels).
  // The scanline is located at pixel coordinates (|src_x|, |src_y0|) and runs
  // to location (|src_x|, |src_y1|).  The scanline is copied (and scaled) to
  // location (|dst_x|, |dst_y0|).  All coordinates are clipped to fit in their
  // respective Images.
  void ScaledCopyColumn(int dst_x,
                        float dst_y0,
                        float dst_y1,
                        int src_x,
                        float src_y0,
                        float src_y1,
                        const Image& src,
                        int filter);

  // Copy the horizontal scanline from |src| to target Image, applying a
  // shear transform to the source pixels.  The shearing angle is determined
  // by the difference between |dst_tx0| and |dst_bx0|.  Only limited angle
  // shearing is supported: up to three source pixels can contribute to a
  // destination pixel; applies shearing only, no scaling and no subpixel
  // source offset.  Does nothing if any of the pixel coordinates fall outside
  // of their respective Images.
  void ShearedCopyScanline(float dst_tx0,
                           float dst_bx0,
                           int dst_y,
                           int src_x0,
                           int src_x1,
                           int src_y,
                           const Image& src);

  // Copy the vertical colum from |src| to target Image, applying a
  // shear transform to the source pixels.  The shearing angle is determined
  // by the difference between |dst_ly0| and |dst_ry0|.  Only limited angle
  // shearing is supported: up to three source pixels can contribute to a
  // destination pixel; applies shearing only, no scaling and no subpixel
  // source offset.  Does nothing if any of the pixel coordinates fall outside
  // of their respective Images.
  void ShearedCopyColumn(int dst_x,
                         float dst_ly0,
                         float dst_ry0,
                         int src_x,
                         int src_y0,
                         int src_y1,
                         const Image& src);
 private:
    Image& target_img_;
};
}  // namespace c_salt

#endif  // EXAMPLES_GRAPHICS_PHOTO_C_SALT_IMAGE_MANIPULATOR_H_

