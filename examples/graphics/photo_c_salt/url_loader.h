// Copyright 2010 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef EXAMPLES_GRAPHICS_PHOTO_C_SALT_URL_LOADER_H_
#define EXAMPLES_GRAPHICS_PHOTO_C_SALT_URL_LOADER_H_

#include <stdint.h>
#include <string>
#include "c_salt/instance.h"

namespace c_salt {

class URLLoader {
 public:
  explicit URLLoader(const Instance& instance);
  virtual ~URLLoader() {}

  // Initiates downloading of |url| resource.
  bool Load(const std::string& url);

  // Called by NPP_StreamAsFile.
  virtual void OnURLLoaded(const void* data, size_t data_length) {}

  // Called by NPP_URLNotify.
  virtual void OnError(Instance::URLLoaderErrorCode error) {}

 private:
  // not implemented
  URLLoader(const URLLoader&);
  URLLoader& operator=(const URLLoader&);

  std::string url_;
  const Instance& instance_;
};

}  // namespace c_salt

#endif  // EXAMPLES_GRAPHICS_PHOTO_C_SALT_URL_LOADER_H_

