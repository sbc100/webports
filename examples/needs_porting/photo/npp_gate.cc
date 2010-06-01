// Copyright 2010 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include <assert.h>
#include <stdio.h>
#include <string.h>
#if defined (__native_client__)
#include <nacl/npupp.h>
#else
#include "third_party/npapi/bindings/npapi.h"
#include "third_party/npapi/bindings/nphostapi.h"
#endif
#include <new>

#include "photo.h"

using photo::Photo;

NPError NPP_New(NPMIMEType mime_type,
                NPP instance,
                uint16_t mode,
                int16_t argc,
                char* argn[],
                char* argv[],
                NPSavedData* saved) {
  extern void InitializePepperExtensions(NPP instance);
  if (instance == NULL) {
    return NPERR_INVALID_INSTANCE_ERROR;
  }

  InitializePepperExtensions(instance);

  Photo* photo = new(std::nothrow) Photo();
  if (photo == NULL) {
    return NPERR_OUT_OF_MEMORY_ERROR;
  }

  instance->pdata = photo;
  return NPERR_NO_ERROR;
}

NPError NPP_Destroy(NPP instance, NPSavedData** save) {
  if (instance == NULL) {
    return NPERR_INVALID_INSTANCE_ERROR;
  }

  Photo* photo = static_cast<Photo*>(instance->pdata);
  if (photo != NULL) {
    delete photo;
  }
  return NPERR_NO_ERROR;
}

// NPP_GetScriptableInstance retruns the NPObject pointer that corresponds to
// NPPVpluginScriptableNPObject queried by NPP_GetValue() from the browser.
NPObject* NPP_GetScriptableInstance(NPP instance) {
  if (instance == NULL) {
    return NULL;
  }

  Photo* photo = static_cast<Photo*>(instance->pdata);
  if (!photo)
    return NULL;
  return photo->GetScriptableObject(instance);
}

NPError NPP_GetValue(NPP instance, NPPVariable variable, void *value) {
  if (NPPVpluginScriptableNPObject == variable) {
    NPObject* scriptable_object = NPP_GetScriptableInstance(instance);
    if (scriptable_object == NULL)
      return NPERR_INVALID_INSTANCE_ERROR;
    *reinterpret_cast<NPObject**>(value) = scriptable_object;
    return NPERR_NO_ERROR;
  }
  return NPERR_INVALID_PARAM;
}

int16_t NPP_HandleEvent(NPP instance, void* event) {
  Photo* photo = static_cast<Photo*>(instance->pdata);
  if (!photo)
    return 0;
  return photo->HandleEvent() ? 1 : 0;
}

NPError NPP_SetWindow(NPP instance, NPWindow* window) {
  if (instance == NULL) {
    return NPERR_INVALID_INSTANCE_ERROR;
  }
  if (window == NULL) {
    return NPERR_GENERIC_ERROR;
  }
  Photo* photo = static_cast<Photo*>(instance->pdata);
  if (photo) {
    return photo->SetWindow() ? NPERR_NO_ERROR : NPERR_GENERIC_ERROR;
  }
  return NPERR_GENERIC_ERROR;
}

NPError NPP_NewStream(NPP instance,
                      NPMIMEType type,
                      NPStream* stream,
                      NPBool seekable,
                      uint16* stype) {
  *stype = NP_ASFILEONLY;
  return NPERR_NO_ERROR;
}


NPError NPP_DestroyStream(NPP instance, NPStream* stream, NPReason reason) {
  return NPERR_NO_ERROR;
}

void NPP_StreamAsFile(NPP instance, NPStream* stream, const char* fname) {
  // Called when NPN_GetURL() has finished downloading the file.
  Photo* photo = static_cast<Photo*>(instance->pdata);
  if (!photo)
    return;
  const int fd = *((const int*)(fname));
  photo->NotifyFileReceived(stream->url, fd, stream->end);
}


int32_t NPP_Write(NPP instance,
                NPStream* stream,
                int32_t offset,
                int32_t len,
                void* buffer) {
  return 0;
}


int32_t NPP_WriteReady(NPP instance, NPStream* stream) {
  return 0;
}

extern "C" {

NPError InitializePluginFunctions(NPPluginFuncs* plugin_funcs) {
  memset(plugin_funcs, 0, sizeof(*plugin_funcs));
  plugin_funcs->version = NPVERS_HAS_PLUGIN_THREAD_ASYNC_CALL;
  plugin_funcs->size = sizeof(*plugin_funcs);
  plugin_funcs->newp = NPP_New;
  plugin_funcs->destroy = NPP_Destroy;
  plugin_funcs->setwindow = NPP_SetWindow;
  plugin_funcs->event = NPP_HandleEvent;
  plugin_funcs->getvalue = NPP_GetValue;
  plugin_funcs->newstream = NPP_NewStream;
  plugin_funcs->destroystream = NPP_DestroyStream;
  plugin_funcs->asfile = NPP_StreamAsFile;
  plugin_funcs->writeready = NPP_WriteReady;
  plugin_funcs->write = NPP_Write;
  return NPERR_NO_ERROR;
}

}  // extern "C"
