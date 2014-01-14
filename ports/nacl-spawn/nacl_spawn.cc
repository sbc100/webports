// Copyright (c) 2014 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Emulates spawning/waiting process by asking JavaScript to do so.

#include <assert.h>
#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

#include <string>

#include "ppapi/cpp/instance.h"
#include "ppapi/cpp/var.h"
#include "ppapi/cpp/var_array.h"
#include "ppapi/cpp/var_dictionary.h"
#include "ppapi_simple/ps_instance.h"

extern char** environ;

struct NaClSpawnReply {
  pthread_mutex_t mu;
  pthread_cond_t cond;
  // Zero or positive on success or -errno on failure.
  int result;
};

// Returns a unique request ID to make all request strings different
// from each other.
static std::string GetRequestId() {
  static int64_t req_id = 0;
  static pthread_mutex_t mu = PTHREAD_MUTEX_INITIALIZER;
  pthread_mutex_lock(&mu);
  int64_t id = ++req_id;
  pthread_mutex_unlock(&mu);
  char buf[64];
  sprintf(buf, "%lld", id);
  return buf;
}

// Handle reply from JavaScript. The key is the request string and the
// value is Zero or positive on success or -errno on failure. The
// user_data must be an instance of NaClSpawnReply.
static void HandleNaClSpawnReply(const pp::Var& key,
                                 const pp::Var& value,
                                 void* user_data) {
  if (!key.is_string() || !value.is_int()) {
    fprintf(stderr, "Invalid parameter for HandleNaClSpawnReply\n");
    fprintf(stderr, "key=%s\n", key.DebugString().c_str());
    fprintf(stderr, "value=%s\n", value.DebugString().c_str());
  }
  assert(key.is_string());
  assert(value.is_int());

  NaClSpawnReply* reply = static_cast<NaClSpawnReply*>(user_data);
  pthread_mutex_lock(&reply->mu);
  reply->result = value.AsInt();
  pthread_cond_signal(&reply->cond);
  pthread_mutex_unlock(&reply->mu);
}

// Sends a spawn/wait request to JavaScript and returns the result.
static int SendRequest(pp::VarDictionary* req) {
  const std::string& req_id = GetRequestId();
  req->Set("id", req_id);

  NaClSpawnReply reply;
  pthread_mutex_init(&reply.mu, NULL);
  pthread_cond_init(&reply.cond, NULL);
  PSInstance* instance = PSInstance::GetInstance();
  instance->RegisterMessageHandler(req_id, &HandleNaClSpawnReply, &reply);

  instance->PostMessage(*req);

  pthread_mutex_lock(&reply.mu);
  pthread_cond_wait(&reply.cond, &reply.mu);
  pthread_mutex_unlock(&reply.mu);

  pthread_cond_destroy(&reply.cond);
  pthread_mutex_destroy(&reply.mu);

  instance->RegisterMessageHandler(req_id, NULL, &reply);
  return reply.result;
}

// Spawn a new NaCl process by asking JavaScript. This function lacks
// a lot of features posix_spawn supports (e.g., handling FDs).
// Returns 0 on success. On error -1 is returned and errno will be set
// appropriately.
extern "C" int nacl_spawn_simple(const char** argv) {
  pp::VarDictionary req;
  req.Set("command", "nacl_spawn");
  pp::VarArray args;
  for (int i = 0; argv[i]; i++)
    args.Set(i, argv[i]);
  req.Set("args", args);
  pp::VarArray envs;
  for (int i = 0; environ[i]; i++)
    envs.Set(i, environ[i]);
  req.Set("envs", envs);
  char cwd[PATH_MAX + 1];
  // TODO(hamaji): Investigate why getcwd crashes. As newlib does not
  // have getwd, nacl-spawn is glibc only right now.
  if (!getwd(cwd))
    assert(0);
  req.Set("cwd", cwd);

  int result = SendRequest(&req);
  if (result < 0) {
    errno = -result;
    return -1;
  }
  return result;
}

// Waits for the specified pid. The semantics of this function is as
// same as waitpid, though this implementation has some restrictions.
// Returns 0 on success. On error -1 is returned and errno will be set
// appropriately.
extern "C" int nacl_waitpid(int pid, int* status, int options) {
  // We only support waiting for a single process.
  assert(pid > 0);
  // No options are supported yet.
  assert(options == 0);

  pp::VarDictionary req;
  req.Set("command", "nacl_wait");

  int result = SendRequest(&req);
  if (result < 0) {
    errno = -result;
    return -1;
  }

  // WEXITSTATUS(s) is defined as ((s >> 8) & 0xff).
  if (status)
    *status = (result & 0xff) << 8;
  return 0;
}
