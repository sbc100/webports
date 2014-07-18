# Copyright (c) 2014 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

GETURL=geturl_$(NACL_ARCH)$(NACL_EXEEXT)

all: $(GETURL)

EXTRA_LIBS=${NACL_CLI_MAIN_LIB} -lppapi_simple -lnacl_spawn -lnacl_io \
	   -lppapi -lppapi_cpp

$(GETURL): geturl.cc
	$(NACLCXX) $(CXXFLAGS) $(LDFLAGS) -o $@ $^ $(EXTRA_LIBS)

clean:
	rm -f $(GETURL)
