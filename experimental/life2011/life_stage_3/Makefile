# Copyright 2011, The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Makefile for Stage 2 of the Life2011 tutorial.

NACLPORTS_ROOT ?= ../../..
INSTALL_ROOT ?= $$HOME/Sites/life2011
INSTALL_DIR ?= $(INSTALL_ROOT)/life_stage_3

CCFILES = life.cc \
          life_application.cc \
          life_module.cc \
          stamp.cc \
          scripting/scripting_bridge.cc

HFILES = life.h \
         life_application.h \
         locking_image_data.h \
         scoped_pixel_lock.h \
         scripting/callback.h \
         scripting/scripting_bridge.h \
         stamp.h \
         threading/condition_lock.h \
         threading/pthread_ext.h \
         threading/scoped_mutex_lock.h

CFLAGS = -Wall -Wno-long-long -pthread -Werror
INCLUDES = -I$(NACL_SDK_ROOT) -I$(NACLPORTS_ROOT)
LDFLAGS = -lppruntime \
          -lppapi_cpp \
          -lplatform \
          -lgio \
          -lpthread \
          -lsrpc \
          $(ARCH_FLAGS)

RELEASE_MODULES = life_x86_32.nexe life_x86_64.nexe
DEBUG_MODULES = life_x86_32_dbg.nexe life_x86_64_dbg.nexe
ALL_MODULES = $(RELEASE_MODULES) $(DEBUG_MODULES)

APPLICATION_FILES = life.html \
                    life.nmf \
                    closure.js \
                    life.js \
                    controllers/stamp_editor.js \
                    controllers/stamp_panel.js \
                    controllers/viewcontroller.js \
                    events/dragger.js \
                    events/event.js \
                    css/life.css \
                    css/stamp_editor.css \
                    css/toolbar.css \
                    img/dead_cell.png \
                    img/live_cell.png \
                    img/minus_button.png \
                    img/pause_button.png \
                    img/play_button.png \
                    img/plus_button.png \
                    img/toolbar-bg.png \
                    $(RELEASE_MODULES)

# The check_variables target is in nacl_build.mk.
all: check_variables $(ALL_MODULES)

# nacl_build.mk has rules to build .o files from .cc files.
-include $(NACLPORTS_ROOT)/common_build_scripts/nacl_build.mk

$(OBJECTS_X86_32) $(OBJECTS_X86_64) \
$(OBJECTS_X86_32_DBG) $(OBJECTS_X86_64_DBG):: $(HFILES)

life_x86_32.nexe: $(OBJECTS_X86_32)
	$(CPP) $^ $(LDFLAGS) -m32 -o $@
	$(NACL_STRIP) $@ -o $@

life_x86_64.nexe: $(OBJECTS_X86_64)
	$(CPP) $^ $(LDFLAGS) -m64 -o $@
	$(NACL_STRIP) $@ -o $@

life_x86_32_dbg.nexe: $(OBJECTS_X86_32_DBG)
	$(CPP) $^ $(LDFLAGS) -m32 -o $@

life_x86_64_dbg.nexe: $(OBJECTS_X86_64_DBG)
	$(CPP) $^ $(LDFLAGS) -m64 -o $@

install: $(APPLICATION_FILES) $(INSTALL_DIR)
	tar cf - $(APPLICATION_FILES) | (cd $(INSTALL_DIR); tar xvf - --exclude="._*")

$(INSTALL_DIR):
	mkdir -p $@

clean:
	-$(RM) -rf *.o */*.o *.obj *.nexe
