# Copyright 2011, The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Main makefile for the Life tutorial.  Descends into each of the tutorial
# stages and builds them, also provides an install target to install all of
# the tutorials.


.PHONY: all install clean

INSTALL_DIR ?= $(HOME)/Sites/life-tutorial

TUTORIALS = life_stage_1 \
            life_stage_2 \
            life_stage_3

APPLICATION_FILES = index.html

all: $(foreach tutorial,$(TUTORIALS),default_$(tutorial))

# Make publish versions of all the modules.
install: $(INSTALL_DIR) \
         $(APPLICATION_FILES) \
         $(foreach tutorial,$(TUTORIALS),install_$(tutorial))
	install $(APPLICATION_FILES) $(INSTALL_DIR)

clean: $(foreach tutorial,$(TUTORIALS),clean_$(tutorial))

# Auto-generate all the install and clean targets.
define TUTORIAL_TARGETS

.PHONY: install_$(1) clean_$(1)

# Default make target for each tutorial.
default_$(1):
	$(MAKE) -C $(1) -f Makefile

# Install target for each tutorial.
install_$(1):
	$(MAKE) -C $(1) -f Makefile install INSTALL_ROOT=$(INSTALL_DIR)

# Clean target for each example
clean_$(1):
	$(MAKE) -C $(1) -f Makefile clean

endef

$(foreach tutorial,$(TUTORIALS),$(eval $(call TUTORIAL_TARGETS,$(tutorial))))

$(INSTALL_DIR):
	mkdir -p $@
