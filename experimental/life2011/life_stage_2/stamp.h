// Copyright 2011 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef STAMP_H_
#define STAMP_H_

#include <ppapi/cpp/point.h>
#include <ppapi/cpp/rect.h>
#include <ppapi/cpp/size.h>

#include <vector>

namespace life {
// A stamp object.  This holds a bitmap for an initial-value stamp.  Applying
// the stamp puts values in the cell bitmap and a pixel buffer.  Stamps are
// initialized using the .LIF 1.05 format (see:
// http://psoup.math.wisc.edu/mcell/ca_files_formats.html). Stamps are always
// rectangular, and have minimum dimensions of (3 x 3).
class Stamp {
 public:
  // Create the default stamp.
  Stamp();
  // Create a stamp using the supplied color and cell buffer.  The color
  // buffer is assumed to be in ARGB format.  Both buffer must have the same
  // dimensions.  The stamp makes a copy of both buffers, so it is safe to
  // delete the passed-in buffers when this ctor returns.
  Stamp(const std::vector<uint32_t>& pixel_buffer,
        const std::vector<uint8_t>& cell_buffer,
        const pp::Size& size);
  virtual ~Stamp();

  // Apply the stamp to the color and cell buffers.  The stamp is cropped to
  // the buffer rectangles.  Both the pixel and cell buffer must have the same
  // dimensions, and are assumed to have matching coordinate systems (that is,
  // (x, y) in the pixel buffer corresponds to the same location in the cell
  // buffer).
  void StampAtPointInBuffers(const pp::Point& point,
                             uint32_t* dest_pixel_buffer,
                             uint8_t* dest_cell_buffer,
                             const pp::Size& buffer_size) const;

  pp::Size size() const {
    return size_;
  }

  // The stamp offset represents the origin of the stamp in the stamp's
  // coordinate system, where (0, 0) is the upper-left corner.
  pp::Point stamp_offset() const {
    return stamp_offset_;
  }
  void set_stamp_offset(const pp::Point& offset) {
    stamp_offset_ = offset;
  }

 private:
  pp::Size size_;
  pp::Point stamp_offset_;
  std::vector<uint32_t> pixel_buffer_;
  std::vector<uint8_t> cell_buffer_;
};

}  // namespace life

#endif  // LIFE_H_

