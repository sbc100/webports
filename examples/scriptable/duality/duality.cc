// Copyright 2008 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.


#include <examples/srpc/duality/duality.h>

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <nacl/nacl_npapi.h>
#include <nacl/nacl_srpc.h>

Duality::Duality()
    : Scriptable() {
  printf("Duality: Duality() was called!\n");
  fflush(stdout);
}

Duality::~Duality() {
  printf("Duality: ~Duality() was called!\n");
  fflush(stdout);
}

bool Duality::SayHello(Scriptable * instance,
                       const NPVariant* args,
                       uint32_t arg_count,
                       NPVariant* result) {
  printf("Duality: Duality::SayHello was called via NPAPI!\n");
  fflush(stdout);
  if (result) {
    const char *msg = "Hello from a specialized Scriptable!";
    const int msg_length = strlen(msg) + 1;
    // Note: |msg_copy| will be freed later on by the browser, so it needs to
    // be allocated here with NPN_MemAlloc().
    char *msg_copy = reinterpret_cast<char*>(NPN_MemAlloc(msg_length));
    strncpy(msg_copy, msg, msg_length);
    STRINGN_TO_NPVARIANT(msg_copy, msg_length - 1, *result);
  }
  return true;
}

void Duality::InitializeMethodTable() {
  printf("Duality: Duality::InitializeMethodTable was called!\n");
  fflush(stdout);
  NPIdentifier say_hello_id = NPN_GetStringIdentifier("SayHello");
  IdentifierToMethodMap::value_type tMethodEntry(say_hello_id,
                                                 &Duality::SayHello);
  method_table_->insert(tMethodEntry);
}

NaClSrpcError Duality::HelloWorld(NaClSrpcChannel *channel,
                                  NaClSrpcArg **in_args,
                                  NaClSrpcArg **out_args) {
  out_args[0]->u.sval = strdup("hello, world.");
  return NACL_SRPC_RESULT_OK;
}

NACL_SRPC_METHOD("helloworld::s", Duality::HelloWorld);
