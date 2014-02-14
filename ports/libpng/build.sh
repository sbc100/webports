#!/bin/bash
# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Override configure step to force it use autotools.  Without
# this the default configure step will see the CMakeList.txt
# file and try to use cmake to configure the project.
ConfigureStep() {
  ConfigureStep_Autotools
}
