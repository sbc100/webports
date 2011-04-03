// Copyright 2011 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "experimental/life2011/life_stage_2/stamp.h"

#include <algorithm>
#include <cstring>
#include <vector>

namespace {
const int32_t kMinimumStampDimension = 3;
inline uint32_t MakeRGBA(uint32_t r, uint32_t g, uint32_t b, uint32_t a) {
  return (((a) << 24) | ((r) << 16) | ((g) << 8) | (b));
}

// Do a simple copy composite from src_buffer into dst_buffer.  Copy the pixels
// contained in |src_rect| to |dst_loc|.  This assumes that all the necessary
// cropping and clipping has been done, and that all the buffer pointers are
// valid.
template <class PixelT> void CopyCompositeToPoint(
    const PixelT* src_buffer,
    int src_row_width,
    const pp::Rect& src_rect,
    PixelT* dst_buffer,
    int dst_row_width,
    const pp::Point& dst_loc) {
  const PixelT* src = src_buffer + src_rect.x() + src_rect.y() * src_row_width;
  PixelT* dst = dst_buffer + dst_loc.x() + dst_loc.y() * dst_row_width;
  for (int y = 0; y < src_rect.height(); ++y) {
    memcpy(dst, src, src_rect.width() * sizeof(PixelT));
    src += src_row_width;
    dst += dst_row_width;
  }
}
}  // namespace

namespace life {
Stamp::Stamp()
    : size_(kMinimumStampDimension, kMinimumStampDimension),
      stamp_offset_(0, 0) {
  // Build the default stamp.
  int buffer_size = size_.GetArea();
  pixel_buffer_.resize(buffer_size);
  cell_buffer_.resize(buffer_size);
  uint32_t green = MakeRGBA(0, 0xE0, 0, 0xFF);
  uint32_t black = MakeRGBA(0, 0, 0, 0xFF);
  pixel_buffer_[0] = pixel_buffer_[1] = pixel_buffer_[2] = green;
  pixel_buffer_[3] = green;
  pixel_buffer_[4] = pixel_buffer_[5] = black;
  pixel_buffer_[6] = black;
  pixel_buffer_[7] = green;
  pixel_buffer_[8] = black;
  cell_buffer_[0] = cell_buffer_[1] = cell_buffer_[2] = 1;
  cell_buffer_[3] = 1;
  cell_buffer_[4] = cell_buffer_[5] = 0;
  cell_buffer_[6] = 0;
  cell_buffer_[7] = 1;
  cell_buffer_[8] = 0;
}

Stamp::Stamp(const std::vector<uint32_t>& pixel_buffer,
             const std::vector<uint8_t>& cell_buffer,
             const pp::Size& size)
    : size_(size), stamp_offset_(0, 0) {
  pixel_buffer_ = pixel_buffer;
  cell_buffer_ = cell_buffer;
}

Stamp::~Stamp() {
}

void Stamp::StampAtPointInBuffers(const pp::Point& point,
                                  uint32_t* dest_pixel_buffer,
                                  uint8_t* dest_cell_buffer,
                                  const pp::Size& buffer_size) {
  // Do a simple COPY composite operation into the pixel and cell buffers.
  int copy_width = size().width();
  int copy_height = size().height();
  // Apply the stamp offset and crop the destination pixel coordinates.
  int src_x = 0;
  int src_y = 0;
  int dst_x = point.x() - stamp_offset().x();
  int dst_y = point.y() - stamp_offset().y();
  if (dst_x < 0) {
    src_x -= dst_x;
    copy_width += dst_x;
    dst_x = 0;
  }
  if (dst_y < 0) {
    src_y -= dst_y;
    copy_height += dst_y;
    dst_y = 0;
  }
  if (dst_x + copy_width > buffer_size.width()) {
    copy_width = buffer_size.width() - dst_x;
  }
  if (dst_y + copy_height > buffer_size.height()) {
    copy_height = buffer_size.height() - dst_y;
  }
  pp::Rect src_rect(src_x, src_y, copy_width, copy_height);
  pp::Point dst_loc(dst_x, dst_y);
  if (dest_pixel_buffer) {
    CopyCompositeToPoint(&pixel_buffer_[0],
                         size().width(),
                         src_rect,
                         dest_pixel_buffer,
                         buffer_size.width(),
                         dst_loc);
  }
  if (dest_cell_buffer) {
    CopyCompositeToPoint(&cell_buffer_[0],
                         size().width(),
                         src_rect,
                         dest_cell_buffer,
                         buffer_size.width(),
                         dst_loc);
  }
}
}  // namespace life
