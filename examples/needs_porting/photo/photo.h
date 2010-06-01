// Copyright 2010 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef PHOTO_H_
#define PHOTO_H_

#include <pthread.h>
#if defined(__native_client__)
#include <nacl/nacl_npapi.h>
#include <nacl/npapi_extensions.h>
#else
#include "third_party/npapi/bindings/npapi.h"
#include "third_party/npapi/bindings/npapi_extensions.h"
#include "third_party/npapi/bindings/nphostapi.h"
#endif
#include <string>
#include <vector>

#include "callback.h"
#include "scripting_bridge.h"

namespace photo {

class Photo {
 public:
  Photo();
  ~Photo();
  void InitializeMethods(photo::ScriptingBridge* bridge);
  void InitializeProperties(photo::ScriptingBridge* bridge);

  bool GetValueForKey(photo::ScriptingBridge* bridge,
                      const NPVariant* args,
                      uint32_t arg_count,
                      NPVariant* return_value);
  bool SetValueForKey(photo::ScriptingBridge* bridge,
                      const NPVariant* args,
                      uint32_t arg_count,
                      NPVariant* value);
  bool GetImageUrl(photo::ScriptingBridge* bridge,
                   NPVariant* return_value);
  bool SetImageUrl(photo::ScriptingBridge* bridge,
                   const NPVariant* value);

  // ModuleInstance methods, these are called from the NPP gate.
  bool HandleEvent();
  bool SetWindow();
  NPObject* GetScriptableObject(NPP instance);
  void NotifyFileReceived(const char* url, const int fd, uint32 size);

 private:
  photo::MethodCallback<Photo>* value_for_key_callback_;
  photo::MethodCallback<Photo>* set_value_for_key_callback_;
  photo::PropertyAccessorCallback<Photo>* image_url_accessor_;
  photo::PropertyMutatorCallback<Photo>* image_url_mutator_;
  std::string image_url_;
  photo::ScriptingBridge* scripting_bridge_;
};

}  // namespace photo

#endif  // PHOTO_H_
