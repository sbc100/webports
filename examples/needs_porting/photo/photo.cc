// Copyright 2010 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "photo.h"

#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(__native_client__)
#include <nacl/nacl_imc.h>
#include <nacl/nacl_npapi.h>
#include <nacl/npapi_extensions.h>
#include <nacl/npruntime.h>
#else
// Building the develop version.
#include "third_party/npapi/bindings/npapi.h"
#include "third_party/npapi/bindings/npapi_extensions.h"
#include "third_party/npapi/bindings/nphostapi.h"
#endif

#include "scripting_bridge.h"

namespace photo {

Photo::Photo()
    : value_for_key_callback_(NULL),
      set_value_for_key_callback_(NULL),
      image_url_accessor_(NULL),
      image_url_mutator_(NULL),
      scripting_bridge_(NULL) {
}

Photo::~Photo() {
  if (scripting_bridge_)
    NPN_ReleaseObject(scripting_bridge_);  // Calls the dtor.
  delete value_for_key_callback_;
  delete set_value_for_key_callback_;
  delete image_url_accessor_;
  delete image_url_mutator_;
}

void Photo::InitializeMethods(photo::ScriptingBridge* bridge) {
  value_for_key_callback_ =
      new photo::MethodCallback<Photo>(this, &Photo::GetValueForKey);
  bridge->AddMethodNamed("valueForKey", value_for_key_callback_);
  set_value_for_key_callback_ =
      new photo::MethodCallback<Photo>(this, &Photo::SetValueForKey);
  bridge->AddMethodNamed("setValueForKey", set_value_for_key_callback_);
}

void Photo::InitializeProperties(photo::ScriptingBridge* bridge) {
  image_url_accessor_ = new photo::PropertyAccessorCallback<Photo>(
      this, &Photo::GetImageUrl);
  image_url_mutator_ = new photo::PropertyMutatorCallback<Photo>(
      this, &Photo::SetImageUrl);
  bridge->AddPropertyNamed("imageUrl",
                           image_url_accessor_,
                           image_url_mutator_);
}

bool Photo::GetValueForKey(photo::ScriptingBridge* bridge,
                           const NPVariant* args,
                           uint32_t arg_count,
                           NPVariant* return_value) {
  return false;
}

bool Photo::SetValueForKey(photo::ScriptingBridge* bridge,
                           const NPVariant* args,
                           uint32_t arg_count,
                           NPVariant* value) {
  return false;
}

bool Photo::GetImageUrl(photo::ScriptingBridge* bridge,
                        NPVariant* return_value) {
  NULL_TO_NPVARIANT(*return_value);
  size_t str_len = image_url_.length();
  if (str_len > 0) {
    // Allocate string memory in the browser, copy the string contents into
    // that and return the result.
    char* browser_str = reinterpret_cast<char*>(NPN_MemAlloc(str_len + 1));
    memcpy(browser_str, image_url_.c_str(), str_len);
    browser_str[str_len] = '\0';
    STRINGN_TO_NPVARIANT(browser_str, str_len, *return_value);
  }
  return true;
}

bool Photo::SetImageUrl(photo::ScriptingBridge* bridge,
                        const NPVariant* value) {
  if (NPVARIANT_IS_STRING(*value)) {
    image_url_ = std::string(value->value.stringValue.UTF8Characters,
                             value->value.stringValue.UTF8Length);
    // Request a file download.  This will eventually call NotifyFileReceived().
    // When the target parameter is NULL, the browser will send the resulting
    // bytes back to our module.
    NPN_GetURL(bridge->npp(), image_url_.c_str(), NULL);
    return true;
  }
  return false;
}

bool Photo::HandleEvent() {
  return false;
}

bool Photo::SetWindow() {
  return false;
}

NPObject* Photo::GetScriptableObject(NPP instance) {
  if (!scripting_bridge_) {
    // This is a synchronous call, and actually returns a ScriptingBridge
    // via the bridge_class function table.ß
    scripting_bridge_ = static_cast<photo::ScriptingBridge*>(
        NPN_CreateObject(instance,&photo::ScriptingBridge::bridge_class));
    InitializeMethods(scripting_bridge_);
    InitializeProperties(scripting_bridge_);
  } else {
    NPN_RetainObject(scripting_bridge_);
  }
  return scripting_bridge_;
}

void Photo::NotifyFileReceived(const char* url, const int fd, uint32 size) {
  // Add the newly downloaded file to the list of internal files.
  printf("Url: %s\n", url);
  printf("fd: %d\n", fd);
  printf("size: %d\n", size);
}


}  // namespace photo
