// Copyright (c) 2014 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Emulates spawning/waiting process by asking JavaScript to do so.

#include "nacl_spawn.h"

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <libgen.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include <string>
#include <vector>

#include "ppapi/cpp/instance.h"
#include "ppapi/cpp/var.h"
#include "ppapi/cpp/var_array.h"
#include "ppapi/cpp/var_dictionary.h"
#include "ppapi_simple/ps_instance.h"

#include "library_dependencies.h"
#include "path_util.h"

extern char** environ;

struct NaClSpawnReply {
  pthread_mutex_t mu;
  pthread_cond_t cond;
  // Zero or positive on success or -errno on failure.
  int result;
  int status;
};

static std::string GetCwd() {
  char cwd[PATH_MAX + 1];
  // TODO(hamaji): Remove this #if and always call getcwd.
  // https://code.google.com/p/naclports/issues/detail?id=109
#if defined(__GLIBC__)
  if (!getwd(cwd))
#else
  if (!getcwd(cwd, PATH_MAX))
#endif
    assert(0);
  return cwd;
}

static std::string GetAbsPath(const std::string& path) {
  assert(!path.empty());
  if (path[0] == '/')
    return path;
  else
    return GetCwd() + '/' + path;
}

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
  if (!key.is_string() || !value.is_dictionary()) {
    fprintf(stderr, "Invalid parameter for HandleNaClSpawnReply\n");
    fprintf(stderr, "key=%s\n", key.DebugString().c_str());
    fprintf(stderr, "value=%s\n", value.DebugString().c_str());
  }
  assert(key.is_string());
  assert(value.is_dictionary());

  pp::VarDictionary valDict(value);
  assert(valDict.HasKey("pid"));

  NaClSpawnReply* reply = static_cast<NaClSpawnReply*>(user_data);
  pthread_mutex_lock(&reply->mu);
  reply->result = valDict.Get("pid").AsInt();
  if (valDict.HasKey("status")) {
    reply->status = valDict.Get("status").AsInt();
  }
  pthread_cond_signal(&reply->cond);
  pthread_mutex_unlock(&reply->mu);
}

// Sends a spawn/wait request to JavaScript and returns the result.
static int SendRequest(pp::VarDictionary* req, int* status) {
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
  if (reply.result >= 0 && status != NULL) {
    *status = reply.status;
  }
  return reply.result;
}

// Adds a file into nmf. |key| is the key for open_resource IRT or
// "program". |filepath| is not a URL yet. JavaScript code is
// responsible to fix them.
static void AddFileToNmf(const std::string& key,
                         const std::string& filepath,
                         pp::VarDictionary* dict) {
#if defined(__pnacl__)
  pp::VarDictionary url;
  url.Set("url", filepath);
  pp::VarDictionary translator;
  translator.Set("pnacl-translator", url);
  pp::VarDictionary arch;
  arch.Set("portable", translator);
  dict->Set(key, arch);
#else
# if defined(__x86_64__)
  static const char kArch[] = "x86-64";
# elif defined(__i686__)
  static const char kArch[] = "x86-32";
# elif defined(__arm__)
  static const char kArch[] = "arm";
# else
#  error "Unknown architecture"
# endif
  pp::VarDictionary url;
  url.Set("url", filepath);
  pp::VarDictionary arch;
  arch.Set(kArch, url);
  dict->Set(key, arch);
#endif
}

static void AddNmfToRequestForShared(
  std::string prog,
  const std::vector<std::string>& dependencies,
  pp::VarDictionary* req) {
  pp::VarDictionary nmf;
  pp::VarDictionary files;
  const char* prog_base = basename(&prog[0]);
  for (size_t i = 0; i < dependencies.size(); i++) {
    std::string dep = dependencies[i];
    const std::string& abspath = GetAbsPath(dep);
    const char* base = basename(&dep[0]);
    // nacl_helper does not pass the name of program and the dynamic
    // loader always uses "main.nexe" as the main binary.
    if (strcmp(prog_base, base) == 0)
      base = "main.nexe";
    if (strcmp(base, "runnable-ld.so") == 0) {
      AddFileToNmf("program", abspath, &nmf);
    } else {
      AddFileToNmf(base, abspath, &files);
    }
  }
  nmf.Set("files", files);
  req->Set("nmf", nmf);
}

static void AddNmfToRequestForStatic(const std::string& prog,
                                     pp::VarDictionary* req) {
  pp::VarDictionary nmf;
  AddFileToNmf("program", GetAbsPath(prog), &nmf);
  req->Set("nmf", nmf);
}

static void VarArrayInsert(
    uint32_t index, pp::Var value, pp::VarArray* dst) {
  dst->SetLength(dst->GetLength() + 1);
  for (uint32_t i = dst->GetLength() - 1; i > index; --i) {
    dst->Set(i, dst->Get(i - 1));
  }
  dst->Set(index, value);
}

static void FindInterpreter(std::string* path) {
  // Check if the path exists.
  if (access(path->c_str(), R_OK) == 0) {
    return;
  }
  // As /bin and /usr/bin are currently only mounted to a memory filesystem
  // in nacl_spawn, programs usually located there are installed to some other
  // location which is included in the PATH.
  // For now, do something non-standard.
  // If the program cannot be found at its full path, strip the program path
  // down to the basename and relying on later path search steps to find the
  // actual program location.
  size_t i = path->find_last_of('/');
  if (i == std::string::npos) {
    return;
  }
  *path = path->substr(i + 1);
}

static bool ExpandShBang(std::string* prog, pp::VarDictionary* req) {
  // Open script.
  int fh = open(prog->c_str(), O_RDONLY);
  if (fh < 0) {
    return false;
  }
  // Read first 4k.
  char buffer[4096];
  ssize_t len = read(fh, buffer, sizeof buffer);
  if (len < 0) {
    close(fh);
    return false;
  }
  // Close script.
  if (close(fh) < 0) {
    return false;
  }
  // At least must have room for #!.
  if (len < 2) {
    errno = ENOEXEC;
    return false;
  }
  // Check if it's a script.
  if (memcmp(buffer, "#!", 2) != 0) {
    // Not a script.
    return true;
  }
  const char* start = buffer + 2;
  // Find the end of the line while also looking for the first space.
  // Mimicking Linux behavior, in which the first space marks a split point
  // where everything before is the interpreter path and everything after is
  // (including spaces) is treated as a single extra argument.
  const char* end = start;
  const char* split = NULL;
  while (buffer - end < len && *end != '\n' && *end != '\r') {
    if (*end == ' ' && split == NULL) {
      split = end;
    }
    ++end;
  }
  // Update command to run.
  pp::Var argsv = req->Get("args");
  assert(argsv.is_array());
  pp::VarArray args(argsv);
  // Set argv[0] in case it was path expanded.
  args.Set(0, *prog);
  std::string interpreter;
  if (split) {
    interpreter = std::string(start, split - start);
    std::string arg(split + 1, end - (split + 1));
    VarArrayInsert(0, arg, &args);
  } else {
    interpreter = std::string(start, end - start);
  }
  FindInterpreter(&interpreter);
  VarArrayInsert(0, interpreter, &args);
  *prog = interpreter;
  return true;
}

static bool UseBuiltInFallback(std::string* prog, pp::VarDictionary* req) {
  if (prog->find('/') == std::string::npos) {
    bool found = false;
    const char* path_env = getenv("PATH");
    std::vector<std::string> paths;
    GetPaths(path_env, &paths);
    if (GetFileInPaths(*prog, paths, prog)) {
      // Update argv[0] to match prog if we ended up changing it.
      pp::Var argsv = req->Get("args");
      assert(argsv.is_array());
      pp::VarArray args(argsv);
      args.Set(0, *prog);
    } else {
      // If the path does not contain a slash and we cannot find it
      // from PATH, we use NMF served with the JavaScript.
      return true;
    }
  }
  return false;
}

// Set the naclType of the request, ideally based on the executable header.
static void LabelNaClType(const std::string& filename, pp::VarDictionary* req) {
  // Open script.
  int fh = open(filename.c_str(), O_RDONLY);
  if (fh < 0) {
    // Default to current nacl type if the file can't be read.
#if defined(__pnacl__)
    req->Set("naclType", "pnacl");
#else
    req->Set("naclType", "nacl");
#endif
    return;
  }
  // Read first 4 bytes.
  char buffer[4];
  ssize_t len = read(fh, buffer, sizeof buffer);
  close(fh);
  // Decide based on the header.
  if (len == 4 && memcmp(buffer, "PEXE", sizeof buffer) == 0) {
    req->Set("naclType", "pnacl");
  } else {
    req->Set("naclType", "nacl");
  }
}

// Adds a NMF to the request if |prog| is stored in HTML5 filesystem.
static bool AddNmfToRequest(std::string prog, pp::VarDictionary* req) {
  LabelNaClType(prog, req);
  if (UseBuiltInFallback(&prog, req)) {
    return true;
  }
  if (access(prog.c_str(), R_OK) != 0) {
    errno = ENOENT;
    return false;
  }

  if (!ExpandShBang(&prog, req)) {
    return false;
  }

  // Relabel nacl/pnacl and check fallback again in case of #! expanded
  // to something else.
  LabelNaClType(prog, req);
  if (UseBuiltInFallback(&prog, req)) {
    return true;
  }

  std::vector<std::string> dependencies;
  if (!FindLibraryDependencies(prog, &dependencies))
    return false;
  if (!dependencies.empty()) {
    AddNmfToRequestForShared(prog, dependencies, req);
    return true;
  }
  // No dependencies means the main binary is statically linked.
  AddNmfToRequestForStatic(prog, req);
  return true;
}

// Spawn a new NaCl process by asking JavaScript. This function lacks
// a lot of features posix_spawn supports (e.g., handling FDs).
// Returns 0 on success. On error -1 is returned and errno will be set
// appropriately.
int spawnve(int mode, const char* path,
            char *const argv[], char *const envp[]) {
  if (NULL == path || NULL == argv[0]) {
    errno = EINVAL;
    return -1;
  }
  if (mode == P_WAIT) {
    int pid = spawnve(P_NOWAIT, path, argv, envp);
    if (pid < 0) {
      return -1;
    }
    int status;
    int result = waitpid(pid, &status, 0);
    if (result < 0) {
      return -1;
    }
    return status;
  } else if (mode == P_NOWAIT || mode == P_NOWAITO) {
    // The normal case.
  } else if (mode == O_OVERLAY) {
    // TODO(bradnelson): Add this by allowing javascript to replace the
    // existing module with a new one.
    errno = ENOSYS;
    return -1;
  } else {
    errno = EINVAL;
    return -1;
  }
  if (NULL == envp) {
    envp = environ;
  }
  pp::VarDictionary req;
  req.Set("command", "nacl_spawn");
  pp::VarArray args;
  for (int i = 0; argv[i]; i++)
    args.Set(i, argv[i]);
  req.Set("args", args);
  pp::VarArray envs;
  for (int i = 0; envp[i]; i++)
    envs.Set(i, envp[i]);
  req.Set("envs", envs);
  req.Set("cwd", GetCwd());

  if (!AddNmfToRequest(path, &req)) {
    errno = ENOENT;
    return -1;
  }

  int result = SendRequest(&req, NULL);
  if (result < 0) {
    errno = -result;
    return -1;
  }
  return result;
}

#if defined(__GLIBC__)
extern "C" pid_t wait(void* status) {
#else
extern "C" pid_t wait(int* status) {
#endif
  return waitpid(-1, static_cast<int*>(status), 0);
}

// Waits for the specified pid. The semantics of this function is as
// same as waitpid, though this implementation has some restrictions.
// Returns 0 on success. On error -1 is returned and errno will be set
// appropriately.
extern "C" pid_t waitpid(int pid, int* status, int options) {

  pp::VarDictionary req;
  req.Set("command", "nacl_wait");
  req.Set("pid", pid);
  req.Set("options", options);

  int rawStatus;
  int result = SendRequest(&req, &rawStatus);
  if (result < 0) {
    errno = -result;
    return -1;
  }

  // WEXITSTATUS(s) is defined as ((s >> 8) & 0xff).
  if (status)
    *status = (rawStatus & 0xff) << 8;
  return result;
}
