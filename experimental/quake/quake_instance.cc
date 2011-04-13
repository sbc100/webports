// Copyright 2011 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include "quake_instance.h"

#include <ppapi/cpp/completion_callback.h>
#include <ppapi/cpp/var.h>
#include <stdlib.h>

#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <tr1/functional>

extern "C" {
#include <SDL_video.h>
extern int quake_main(int argc, char* argv[]);
#include <SDL.h>
#include <SDL_nacl.h>
}

#include "nacl_file.h"

namespace nacl_quake {

QuakeInstance::QuakeInstance(PP_Instance instance)
    : pp::Instance(instance),
      quake_main_thread_(NULL),
      width_(0),
      height_(0) {
  std::printf("Created instance.\n");
}

QuakeInstance::~QuakeInstance() {
  if (quake_main_thread_) {
    pthread_join(quake_main_thread_, NULL);
  }
}

void QuakeInstance::DidChangeView(const pp::Rect& position,
                                const pp::Rect& clip) {
  //std::printf("Changing view, (%d, %d) to (%d, %d).\n", width_, height_,
  //            position.size().width(), position.size().height());
  if (position.size().width() == width() &&
      position.size().height() == height())
    return;  // Size didn't change, no need to update anything.

  // HACK HACK HACK.  Apparently this is so we only initialize video once.
  if (width_ && height_)
    return;

  width_ = position.size().width();
  height_ = position.size().height();

  SDL_NACL_SetInstance(pp_instance(), width_, height_);
  int lval = SDL_Init(SDL_INIT_VIDEO);
  //assert(lval >= 0);
}

void QuakeInstance::FilesFinished() {
  pthread_create(&quake_main_thread_, NULL, LaunchQuake, this);
}

bool QuakeInstance::Init(uint32_t argc, const char* argn[], const char* argv[]) {
  //std::printf("Init called.  Setting up files.\n");
  using nacl_file::FileManager;
  FileManager::set_pp_instance(this);
  FileManager::set_ready_func(std::tr1::bind(&QuakeInstance::FilesFinished,
                                             this));
  FileManager::Fetch("id1/config.cfg", 1724u);
  FileManager::Fetch("id1/pak0.pak", 18689235u);
  /*
  #include "file_list.h"
  size_t i = 0;
  while (file_list[i]) {
    FileManager::Fetch(file_list[i]);
    ++i;
  }
  return true;
  */
}

bool QuakeInstance::HandleInputEvent(const PP_InputEvent& event) {
  SDL_NACL_PushEvent(&event);
  return true;
}

void* QuakeInstance::LaunchQuake(void* param) {
  //std::printf("Launching Quake.\n");
  quake_main(0, NULL);

  return NULL;
}

}  // namespace nacl_quake
