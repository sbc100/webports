// Copyright 2011 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef SCOPED_PIXEL_LOCK_H_
#define SCOPED_PIXEL_LOCK_H_

namespace life {

class Life;

// A small helper RAII class used to acquire and release the pixel lock.  This
// class is a friend of the Life class.
class ScopedPixelLock {
 public:
  explicit ScopedPixelLock(Life* image_owner) : image_owner_(image_owner) {
    pixels_ = LockPixels();
  }

  ~ScopedPixelLock() {
    pixels_ = NULL;
    UnlockPixels();
  }

  uint32_t* pixels() const {
    return pixels_;
  }
 private:
  // Acquire the lock in |image_owner_| that governs the pixel buffer.  Return
  // a pointer to the locked pixel buffer if successful; return NULL otherwise.
  uint32_t* LockPixels() {
    uint32_t* pixels = NULL;
    if (image_owner_ != NULL) {
      if (pthread_mutex_lock(&image_owner_->pixel_buffer_mutex_) ==
          PTHREAD_MUTEX_SUCCESS) {
        if (image_owner_->pixel_buffer_ != NULL &&
            !image_owner_->pixel_buffer_->is_null()) {
          pixels = static_cast<uint32_t*>(image_owner_->pixel_buffer_->data());
        }
      }
    }
    return pixels;
  }

  // Release the lock governing the pixel bugger in |image_owner_|.
  void UnlockPixels() {
    if (image_owner_) {
      pthread_mutex_unlock(&image_owner_->pixel_buffer_mutex_);
    }
  }

  Life* image_owner_;  // Weak reference.
  uint32_t* pixels_;  // Weak reference.
};
}  // namespace life

#endif  // SCOPED_PIXEL_LOCK_H_

