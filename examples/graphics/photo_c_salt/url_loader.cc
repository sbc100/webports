// Copyright 2010 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "examples/graphics/photo_c_salt/url_loader.h"
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/stat.h>

namespace c_salt {

URLLoader::URLLoader(const Instance& instance)
  : instance_(instance) {
}

bool URLLoader::Load(const std::string& url) {
  NPError err = NPN_GetURLNotify(instance_.npp_instance(),
                                 url.c_str(),
                                 "",
                                 this);
  return (NPERR_NO_ERROR != err);
}
}  // namespace c_salt

