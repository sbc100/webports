/*
 * Copyright (c) 2011 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <assert.h>
#include <stdio.h>
#include <unistd.h>

#include <SDL.h>
#include "earth.h"

#include "nacl/nacl_log.h"

#define WIDTH 512
#define HEIGHT 512
#define BPP 4
#define DEPTH 32

void DrawScreen(SDL_Surface* screen, SDL_Surface* drawing_surface,
                uint32_t *image_data) {
  assert(NULL != drawing_surface);
  assert(NULL != screen);
  Earth_Draw((uint32_t*)image_data, screen->w, screen->h);

  if (0 != SDL_SetAlpha(drawing_surface, 0, 255)) {
    NaClLog(0, "SDL_SetAlpha failed\n");
  }
  if (0 != SDL_BlitSurface(drawing_surface, NULL, screen, NULL)) {
    NaClLog(0, "SDL_BlitSurface failed\n");
    return;
  }
  SDL_Flip(screen);
}


/* NOTE: SDL on other platform commonly hijacks main() using a #define,
 * and should do the same for Native Client since Native Client Pepper
 * plugins are not currently allowed to define main() themselves.
 * Note that SDL_main is invoked by PluginInstance::sdl_thread() in
 * pepper_plugin.cc, also in this project. At some point pepper_plugin.cc
 * should be moved into the NaCl SDL port, rather than including it in
 * the plugin.
 */
#ifdef __native_client__
#define main SDL_main
#endif
int main(int argc, const char* argv[])
{
  static uint32_t image_data[WIDTH][HEIGHT];
  SDL_Surface *screen, *drawing_surface;
  SDL_Event event;
  int keypress = 0;

  NaClLog(0, "sdl_main: initializing Earth\n");

  Earth_Init(0, NULL, NULL);
  if (SDL_Init(SDL_INIT_VIDEO) < 0 ) return 1;
  if (!(screen = SDL_SetVideoMode(WIDTH, HEIGHT, DEPTH,
                                  SDL_FULLSCREEN|SDL_HWSURFACE))) {
    SDL_Quit();
    return 1;
  }
  drawing_surface = SDL_CreateRGBSurfaceFrom(image_data, WIDTH, HEIGHT,
                                  DEPTH, BPP*WIDTH,
                                  EARTH_R_MASK, EARTH_G_MASK, EARTH_B_MASK, 0);
  if (NULL == drawing_surface) {
    SDL_Quit();
    return 1;
  }

  while (!keypress) {
    /* NOTE: This demo is drawing frames as fast as possible, possibly
     * exceeding the display frame-rate. It ought to be possible to
     * use a timestamp before and after drawing, together with a call
     * nanosleep(), to avoid unuseful drawing. Alternatively an SDL
     * timer event could be used. The SDL implementation might also
     * throttle Flush() calls to the framerate frequence.
     */
    DrawScreen(screen, drawing_surface, (uint32_t*)image_data);
    while (SDL_PollEvent(&event)) {
      switch (event.type) {
      case SDL_QUIT:
        keypress = 1;
        break;
      case SDL_KEYDOWN:
        keypress = 1;
        break;
      }
    }
  }
  SDL_FreeSurface(drawing_surface);
  SDL_Quit();
  return 0;
}
