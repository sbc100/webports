// Copyright 2010 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "examples/graphics/photo_c_salt/image.h"
#include <string.h>
#include <stdio.h>
extern "C" {
#include <jpeglib.h>
#include <jerror.h>
}
#include <algorithm>
#include "examples/graphics/photo_c_salt/fastmath.h"
#include "examples/graphics/photo_c_salt/image-inl.h"

// JPEG reading helper.
extern void jpeg_mem_src(j_decompress_ptr cinfo,
                         unsigned char * inbuffer,
                         uint32_t insize);

namespace c_salt {

Image::Image()
    : width_(0),
      height_(0),
      size_(0),
      background_color_(c_salt::MakeARGB(0, 0, 0, 0xFF)) {
}

Image::Image(const Image& other) {
  *this = other;
}

Image::~Image() {
}

Image& Image::operator=(const Image& other) {
  background_color_ = other.background_color_;
  width_ = other.width_;
  height_ = other.height_;
  size_ = width_ * height_;
  if (size_ != 0) {
    pixels_.reset(new uint32_t[size_]);
    uint32_t* pixels_src = other.pixels_.get();
    uint32_t* pixels_dst = pixels_.get();
    if ((NULL != pixels_src) && (NULL != pixels_dst)) {
      memcpy(pixels_dst, pixels_src, size_ * sizeof(*pixels_src));
    } else {
      width_ = 0;
      height_ = 0;
      size_ = 0;
    }
  }
  return *this;
}

void Image::Resize(int width, int height) {
  width_ = std::max(width, 1);
  height_ = std::max(height, 1);
  size_t newsize = width_ * height_;
  if (newsize > size_) {
    size_ = newsize;
    pixels_.reset(new uint32_t[size_]);
  }
}

void Image::Erase() {
  int size = width_ * height_;
  for (int i = 0; i < size; i++)
    pixels_[i] = background_color_;
}

bool Image::InitWithData(const void* data, size_t data_length) {
  struct jpeg_decompress_struct cinfo;
  struct jpeg_error_mgr jerr;
  cinfo.err = jpeg_std_error(&jerr);
  jpeg_create_decompress(&cinfo);
  jpeg_mem_src(&cinfo,
               static_cast<unsigned char*>(const_cast<void*>(data)),
               data_length);
  jpeg_read_header(&cinfo, TRUE);
  jpeg_start_decompress(&cinfo);

  Resize(cinfo.output_width, cinfo.output_height);

  uint8_t* src_scanline =
      static_cast<uint8_t*>(malloc((cinfo.output_width * 3) + 16));
  for (uint32_t i = 0; i < cinfo.output_height; i++) {
    jpeg_read_scanlines(&cinfo, &src_scanline, 1);

    // Copy the RGB scanline from the JPEG file to the ARGB Image buffer.
    uint8_t* tmp_src_scanline = src_scanline;
    for (uint32_t j = 0; j < cinfo.output_width; j++) {
      uint8_t r = tmp_src_scanline[0];
      uint8_t g = tmp_src_scanline[1];
      uint8_t b = tmp_src_scanline[2];
      SetPixelNoClip(j, i, c_salt::MakeARGB(r, g, b, 0xFF));
      tmp_src_scanline += 3;
    }
  }
  free(src_scanline);
  return true;
}
}  // namespace c_salt

