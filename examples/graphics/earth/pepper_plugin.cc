// Copyright (c) 2011 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
#ifdef __native_client__

#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>

#include <ppapi/cpp/instance.h>
#include <ppapi/cpp/module.h>
#include <ppapi/cpp/rect.h>
#include <ppapi/cpp/size.h>

#include <SDL_video.h>
extern int SDL_main(int argc, const char *argv[]);
#include <SDL.h>
#include <SDL_nacl.h>

// By declaring kill here, we prevent it from being pulled from libnosys.a
// thereby avoiding the compiler warning, and getting a potentially useful
// printf if somebody actually tries to use kill().
extern "C" int kill(pid_t pid, int sig) {
  printf("WARNING: kill(%d, %d). Kill is not implemented for Native Client\n",
         pid, sig);
  return -1;
}

class PluginInstance : public pp::Instance {
 public:
  explicit PluginInstance(PP_Instance instance) : pp::Instance(instance),
                          sdl_main_thread_(0),
                          width_(0),
                          height_(0) {
    printf("PluginInstance\n");
  }
  ~PluginInstance() {
    if (sdl_main_thread_) {
      pthread_join(sdl_main_thread_, NULL);
    }
  }

  virtual void DidChangeView(const pp::Rect& position, const pp::Rect& clip) {
    printf("did change view, new %dx%d, old %dx%d\n",
           position.size().width(), position.size().height(),
           width_, height_);

    if (position.size().width() == width_ &&
        position.size().height() == height_)
      return;  // Size didn't change, no need to update anything.

    if (sdl_thread_started_ == false) {
      width_ = position.size().width();
      height_ = position.size().height();

      SDL_NACL_SetInstance(pp_instance(), width_, height_);
      // It seems this call to SDL_Init is required. Calling from
      // sdl_main() isn't good enough.
      // Perhaps it must be called from the main thread?
      int lval = SDL_Init(SDL_INIT_VIDEO);
      assert(lval >= 0);
      if (0 == pthread_create(&sdl_main_thread_, NULL, sdl_thread, this)) {
        sdl_thread_started_ = true;
      }
    }
  }

  bool HandleInputEvent(const PP_InputEvent& event) {
    SDL_NACL_PushEvent(&event);
    return true;
  }

  bool Init(int argc, const char* argn[], const char* argv[]) {
    return true;
  }

 private:
  bool sdl_thread_started_;
  pthread_t sdl_main_thread_;
  int width_;
  int height_;

  static void* sdl_thread(void* param) {
    SDL_main(0, NULL);
    return NULL;
  }
};

class PepperModule : public pp::Module {
 public:
  // Create and return a PluginInstanceInstance object.
  virtual pp::Instance* CreateInstance(PP_Instance instance) {
    printf("CreateInstance\n");
    return new PluginInstance(instance);
  }
};

namespace pp {
  Module* CreateModule() {
    printf("CreateModule\n");
    return new PepperModule();
  }
}  // namespace pp

#endif // __native_client__
