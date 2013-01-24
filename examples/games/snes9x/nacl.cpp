/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <cstdio>

#include "snes9x.h"
#include "controls.h"
#include "blit.h"
#include "ppu.h"
#include "nacl.h"


struct GUIData {
  uint8 *image_data;
  uint32 bytes_per_line;
  uint8 *blit_screen;
  uint32 blit_screen_pitch;
  int video_mode;
};

GUIData GUI;

EventQueue event_queue;

enum {
  VIDEOMODE_BLOCKY = 1,
  VIDEOMODE_TV,
  VIDEOMODE_SMOOTH,
  VIDEOMODE_SUPEREAGLE,
  VIDEOMODE_2XSAI,
  VIDEOMODE_SUPER2XSAI,
  VIDEOMODE_EPX,
  VIDEOMODE_HQ2X,
  VIDEOMODE_HQ3X,
  TOTAL_VIDEOMODE
};

typedef void (*Blitter) (uint8 *, int, uint8 *, int, int, int);
static void S9xPutImage (int width, int height);
static void Convert16To24 (int width, int height);


void S9xNaclInit(uint32 *data, uint32 pitch) {
  printf("S9xNaclInit() %x, %d\n", data, pitch);
  GUI.image_data = (uint8 *) data;
  GUI.bytes_per_line = pitch;
  GUI.video_mode = VIDEOMODE_SUPER2XSAI;
  Settings.DisplayFrameRate = true;

  const int kMaxFactor = 3;
  GUI.blit_screen = (uint8 *) malloc((SNES_WIDTH * kMaxFactor) * 4 *
      (SNES_HEIGHT_EXTENDED * kMaxFactor));
  GUI.blit_screen_pitch = (SNES_WIDTH * kMaxFactor) * 4;

  GFX.Pitch = SNES_WIDTH * 2 * 2;
  GFX.Screen = (uint16 *) malloc(GFX.Pitch * (SNES_HEIGHT_EXTENDED * 2));

  S9xSetRenderPixelFormat(RGB565);

  S9xGraphicsInit();

  S9xBlitFilterInit();
  S9xBlit2xSaIFilterInit();
  S9xBlitHQ2xFilterInit();
}

void S9xNaclDraw(int width, int height) {
  S9xPutImage(width, height);
}

static void S9xPutImage (int width, int height) {
  static int prevWidth = 0, prevHeight = 0;
  int copyWidth, copyHeight;
  Blitter blitFn = NULL;

  if (width <= SNES_WIDTH) {
    copyWidth  = width  * 2;
    copyHeight = height * 2;

    switch (GUI.video_mode) {
      case VIDEOMODE_BLOCKY:     blitFn = S9xBlitPixSimple2x2; break;
      case VIDEOMODE_TV:         blitFn = S9xBlitPixTV2x2; break;
      case VIDEOMODE_SMOOTH:     blitFn = S9xBlitPixSmooth2x2; break;
      case VIDEOMODE_SUPEREAGLE: blitFn = S9xBlitPixSuperEagle16; break;
      case VIDEOMODE_2XSAI:      blitFn = S9xBlitPix2xSaI16; break;
      case VIDEOMODE_SUPER2XSAI: blitFn = S9xBlitPixSuper2xSaI16; break;
      case VIDEOMODE_EPX:        blitFn = S9xBlitPixEPX16; break;
      case VIDEOMODE_HQ2X:       blitFn = S9xBlitPixHQ2x16; break;
      case VIDEOMODE_HQ3X:
        copyWidth  = width * 3;
        copyHeight = height * 3;
        blitFn = S9xBlitPixHQ3x16;
        break;
    }
  } else if (height <= SNES_HEIGHT_EXTENDED) {
    copyWidth  = width;
    copyHeight = height * 2;

    switch (GUI.video_mode) {
      default:           blitFn = S9xBlitPixSimple1x2; break;
      case VIDEOMODE_TV: blitFn = S9xBlitPixTV1x2; break;
    }
  } else {
    copyWidth  = width;
    copyHeight = height;
    blitFn = S9xBlitPixSimple1x1;
  }

  blitFn((uint8 *) GFX.Screen, GFX.Pitch, GUI.blit_screen,
         GUI.blit_screen_pitch, width, height);

  if (copyHeight < prevHeight) {
    for (int y = 0; y < copyHeight; ++y) {
      uint32 *dst = (uint32 *) (GUI.blit_screen + y * GUI.blit_screen_pitch +
                    copyWidth * 2);
      memset(dst, -1, (prevWidth - copyWidth) * 4);
    }
    for (int y = copyHeight; y < prevHeight; ++y) {
      uint32 *dst = (uint32 *) (GUI.blit_screen + y * GUI.blit_screen_pitch);
      memset(dst, -1, prevWidth * 4);
    }
    Convert16To24(prevWidth, prevHeight);
  } else {
    Convert16To24(copyWidth, copyHeight);
  }

  prevWidth  = copyWidth;
  prevHeight = copyHeight;
}

static void Convert16To24 (int width, int height) {
  for (int y = 0; y < height; y++) {
    uint16 *s = (uint16 *) (GUI.blit_screen + y * GUI.blit_screen_pitch);
    uint32 *d = (uint32 *) (GUI.image_data + y * GUI.bytes_per_line);

    for (int x = 0; x < width; x++) {
      uint32 pixel = *s++;
      // +3 is to convert a 5-bit color to 8-bit
      *d++ = 0xff000000 |
          (((pixel >> 11) & 0x1f) << (16 + 3)) |
          (((pixel >>  6) & 0x1f) << ( 8 + 3)) |
          (((pixel      ) & 0x1f) << ( 0 + 3));
    }
  }
}


const char* KEY_NAME[] = {
  "J1_UP", "J1_DOWN", "J1_LEFT", "J1_RIGHT", "J1_START", "J1_SELECT",
  "J1_A", "J1_B", "J1_X", "J1_Y", "J1_L", "J1_R",

  "J2_UP", "J2_DOWN", "J2_LEFT", "J2_RIGHT", "J2_START", "J2_SELECT",
  "J2_A", "J2_B", "J2_X", "J2_Y", "J2_L", "J2_R",

  "SAVE", "LOAD",
  "SAVE_1", "SAVE_2", "SAVE_3", "SAVE_4", "SAVE_5", "SAVE_6", "SAVE_7",
  "SAVE_8", "SAVE_9",
  "LOAD_1", "LOAD_2", "LOAD_3", "LOAD_4", "LOAD_5", "LOAD_6", "LOAD_7",
  "LOAD_8", "LOAD_9",
};

int KeyNameToKey(const string& name) {
  for (int i = 0; i < sizeof(KEY_NAME) / sizeof(char*); ++i) {
    if (name == KEY_NAME[i]) {
      return i;
    }
  }
  printf("warning: key not found: %s\n", name.c_str());
  return -1;
}

void S9xNaclMapInput() {
#define MapKey(name, command) \
  S9xMapButton(KeyNameToKey(name), S9xGetCommandT(command), false);

  MapKey("J1_UP", "Joypad1 Up");
  MapKey("J1_DOWN", "Joypad1 Down");
  MapKey("J1_LEFT", "Joypad1 Left");
  MapKey("J1_RIGHT", "Joypad1 Right");
  MapKey("J1_START", "Joypad1 Start");
  MapKey("J1_SELECT", "Joypad1 Select");
  MapKey("J1_A", "Joypad1 A");
  MapKey("J1_B", "Joypad1 B");
  MapKey("J1_X", "Joypad1 X");
  MapKey("J1_Y", "Joypad1 Y");
  MapKey("J1_L", "Joypad1 L");
  MapKey("J1_R", "Joypad1 R");

  MapKey("J2_UP", "Joypad2 Up");
  MapKey("J2_DOWN", "Joypad2 Down");
  MapKey("J2_LEFT", "Joypad2 Left");
  MapKey("J2_RIGHT", "Joypad2 Right");
  MapKey("J2_START", "Joypad2 Start");
  MapKey("J2_SELECT", "Joypad2 Select");
  MapKey("J2_A", "Joypad2 A");
  MapKey("J2_B", "Joypad2 B");
  MapKey("J2_X", "Joypad2 X");
  MapKey("J2_Y", "Joypad2 Y");
  MapKey("J2_L", "Joypad2 L");
  MapKey("J2_R", "Joypad2 R");

  MapKey("SAVE", "SaveFreezeFile");
  MapKey("LOAD", "LoadFreezeFile");
  MapKey("SAVE_1", "QuickSave001");
  MapKey("SAVE_2", "QuickSave002");
  MapKey("SAVE_3", "QuickSave003");
  MapKey("SAVE_4", "QuickSave004");
  MapKey("SAVE_5", "QuickSave005");
  MapKey("SAVE_6", "QuickSave006");
  MapKey("SAVE_7", "QuickSave007");
  MapKey("SAVE_8", "QuickSave008");
  MapKey("SAVE_9", "QuickSave009");
  MapKey("LOAD_1", "QuickLoad001");
  MapKey("LOAD_2", "QuickLoad002");
  MapKey("LOAD_3", "QuickLoad003");
  MapKey("LOAD_4", "QuickLoad004");
  MapKey("LOAD_5", "QuickLoad005");
  MapKey("LOAD_6", "QuickLoad006");
  MapKey("LOAD_7", "QuickLoad007");
  MapKey("LOAD_8", "QuickLoad008");
  MapKey("LOAD_9", "QuickLoad009");

  MapKey("PAUSE", "Pause");
  MapKey("RESET", "SoftReset");
#undef MapKey
}

void S9xResizeWindow(int mode) {
  if (mode > 0 && mode < TOTAL_VIDEOMODE) {
    GUI.video_mode = mode;
  }
}

void S9xProcessEvents (bool8 block) {
  while (block || !event_queue.empty()) {
    Event* event = event_queue.dequeue(false);

    if (event->key == "TURBO") {
      if (event->act == "down") {
        Settings.TurboMode = TRUE;
      } else {
        Settings.TurboMode = FALSE;
      }
      continue;
    } else if (event->key == "PAUSE" && event->act == "down") {
      Settings.Paused = !Settings.Paused;
      continue;
    } else if (event->key == "FPS") {
      Settings.DisplayFrameRate = !Settings.DisplayFrameRate;
    }

    int key = KeyNameToKey(event->key);
    if (key != -1) {
      if (event->act == "down") {
        S9xReportButton(key, true);
      } else if (event->act == "up") {
        S9xReportButton(key, false);
      } else {
        printf("The button is not reported due to unknown action: %s\n",
               event->act.c_str());
      }
    }
    delete event;
  }
}
