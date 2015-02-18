// Copyright (c) 2014 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Emulates spawning/waiting process by asking JavaScript to do so.

// Include quoted spawn.h first so we can build in the presence of an installed
// copy of nacl-spawn.
#define IN_NACL_SPAWN_CC
#include "spawn.h"

#include "nacl_main.h"

#include <netinet/in.h>
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <libgen.h>
#include <limits.h>
#include <locale.h>
#include <irt.h>
#include <irt_dev.h>
#include <netinet/in.h>
#include <setjmp.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/socket.h>
#include <sys/stat.h>
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

int nacl_spawn_pid;
int nacl_spawn_ppid;

struct NaClSpawnReply {
  pthread_mutex_t mu;
  pthread_cond_t cond;

  pp::VarDictionary result;
};


// Get an environment variable as an int, or return -1 if the value cannot
// be converted to an int.
static int getenv_as_int(const char *env) {
  const char* env_str = getenv(env);
  if (!env_str) {
    return -1;
  }
  errno = 0;
  int env_int = strtol(env_str, NULL, 0);
  if (errno) {
    return -1;
  }
  return env_int;
}

static int mkdir_checked(const char* dir) {
  int rtn =  mkdir(dir, S_IRWXU | S_IRWXG | S_IRWXO);
  if (rtn != 0) {
    fprintf(stderr, "mkdir '%s' failed: %s\n", dir, strerror(errno));
  }
  return rtn;
}

static int do_mount(const char *source, const char *target,
                    const char *filesystemtype, unsigned long mountflags,
                    const void *data) {
  NACL_LOG("mount[%s] '%s' at '%s'\n", filesystemtype, source, target);
  return mount(source, target, filesystemtype, mountflags, data);
}

extern void nacl_setup_env() {
  umount("/");
  do_mount("", "/", "memfs", 0, NULL);

  // Setup common environment variables, but don't override those
  // set already by ppapi_simple.
  setenv("HOME", "/home/user", 0);
  setenv("PATH", "/bin", 0);
  setenv("USER", "user", 0);
  setenv("LOGNAME", "user", 0);

  const char* home = getenv("HOME");
  mkdir_checked("/home");
  mkdir_checked(home);
  mkdir_checked("/tmp");
  mkdir_checked("/bin");
  mkdir_checked("/etc");
  mkdir_checked("/mnt");
  mkdir_checked("/mnt/http");
  mkdir_checked("/mnt/html5");

  const char* data_url = getenv("NACL_DATA_URL");
  if (!data_url)
    data_url = "./";
  NACL_LOG("NACL_DATA_URL=%s\n", data_url);

  const char* mount_flags = getenv("NACL_DATA_MOUNT_FLAGS");
  if (!mount_flags)
    mount_flags = "";
  NACL_LOG("NACL_DATA_MOUNT_FLAGS=%s\n", mount_flags);

  if (do_mount(data_url, "/mnt/http", "httpfs", 0, mount_flags) != 0) {
    perror("mounting http filesystem at /mnt/http failed");
  }

  if (do_mount("/", "/mnt/html5", "html5fs", 0, "type=PERSISTENT") != 0) {
    perror("Mounting HTML5 filesystem in /mnt/html5 failed");
  } else {
    mkdir("/mnt/html5/home", 0777);
    struct stat st;
    if (stat("/mnt/html5/home", &st) < 0 || !S_ISDIR(st.st_mode)) {
      perror("Unable to create home directory in persistent storage");
    } else {
      if (do_mount("/home", home, "html5fs", 0, "type=PERSISTENT") != 0) {
        fprintf(stderr, "Mounting HTML5 filesystem in %s failed.\n", home);
      }
    }
  }

  if (do_mount("/", "/tmp", "html5fs", 0, "type=TEMPORARY") != 0) {
    perror("Mounting HTML5 filesystem in /tmp failed");
  }

  /* naclprocess.js sends the current working directory using this
   * environment variable. */
  const char* pwd = getenv("PWD");
  if (pwd != NULL) {
    if (chdir(pwd)) {
      fprintf(stderr, "chdir() to %s failed: %s\n", pwd, strerror(errno));
    }
  }

  // Tell the NaCl architecture to /etc/bashrc of mingn.
#if defined(__x86_64__)
  static const char kNaClArch[] = "x86_64";
#elif defined(__i686__)
  static const char kNaClArch[] = "i686";
#elif defined(__arm__)
  static const char kNaClArch[] = "arm";
#elif defined(__pnacl__)
  static const char kNaClArch[] = "pnacl";
#else
# error "Unknown architecture"
#endif
  // Set NACL_ARCH with a guess if not set (0 == set if not already).
  setenv("NACL_ARCH", kNaClArch, 0);
  // Set NACL_BOOT_ARCH if not inherited from a parent (0 == set if not already
  // set). This will let us prefer PNaCl if we started with PNaCl (for tests
  // mainly).
  setenv("NACL_BOOT_ARCH", kNaClArch, 0);

  setlocale(LC_CTYPE, "");

  nacl_spawn_pid = getenv_as_int("NACL_PID");
  nacl_spawn_ppid = getenv_as_int("NACL_PPID");
}

static std::string GetCwd() {
  char cwd[PATH_MAX] = ".";
  if (!getcwd(cwd, PATH_MAX)) {
    NACL_LOG("getcwd failed: %s\n", strerror(errno));
    assert(0);
  }
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
  NaClSpawnReply* reply = static_cast<NaClSpawnReply*>(user_data);
  pthread_mutex_lock(&reply->mu);

  reply->result = valDict;

  pthread_cond_signal(&reply->cond);
  pthread_mutex_unlock(&reply->mu);
}

// Sends a spawn/wait request to JavaScript and returns the result.
static pp::VarDictionary SendRequest(pp::VarDictionary* req) {
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

// Adds a file into nmf. |key| is the key for open_resource IRT or
// "program". |filepath| is not a URL yet. JavaScript code is
// responsible to fix them. |arch| is the architecture string.
static void AddFileToNmf(const std::string& key,
                         const std::string& arch,
                         const std::string& filepath,
                         pp::VarDictionary* dict) {
  pp::VarDictionary url;
  url.Set("url", filepath);
  pp::VarDictionary archd;
  archd.Set(arch, url);
  dict->Set(key, archd);
}

static void AddNmfToRequestForShared(
    std::string prog,
    const std::string& arch,
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
      AddFileToNmf("program", arch, abspath, &nmf);
    } else {
      AddFileToNmf(base, arch, abspath, &files);
    }
  }
  nmf.Set("files", files);
  req->Set("nmf", nmf);
}

static void AddNmfToRequestForStatic(const std::string& prog,
                                     const std::string& arch,
                                     pp::VarDictionary* req) {
  pp::VarDictionary nmf;
  AddFileToNmf("program", arch, GetAbsPath(prog), &nmf);
  req->Set("nmf", nmf);
}

static void AddNmfToRequestForPNaCl(const std::string& prog,
                                    pp::VarDictionary* req) {
  pp::VarDictionary nmf;

  pp::VarDictionary url;
  url.Set("url", GetAbsPath(prog));
  pp::VarDictionary translate;
  translate.Set("pnacl-translate", url);
  pp::VarDictionary archd;
  archd.Set("portable", translate);
  nmf.Set("program", archd);
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

// Check if a file is a pnacl type file.
// If the file can't be read, return false.
static bool IsPNaClType(const std::string& filename) {
  // Open script.
  int fh = open(filename.c_str(), O_RDONLY);
  if (fh < 0) {
    // Default to nacl type if the file can't be read.
    return false;
  }
  // Read first 4 bytes.
  char buffer[4];
  ssize_t len = read(fh, buffer, sizeof buffer);
  close(fh);
  // Decide based on the header.
  return len == 4 && memcmp(buffer, "PEXE", sizeof buffer) == 0;
}

// Adds a NMF to the request if |prog| is stored in HTML5 filesystem.
static bool AddNmfToRequest(std::string prog, pp::VarDictionary* req) {
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

  // Check fallback again in case of #! expanded to something else.
  if (UseBuiltInFallback(&prog, req)) {
    return true;
  }

  // Check for pnacl.
  if (IsPNaClType(prog)) {
    AddNmfToRequestForPNaCl(prog, req);
    return true;
  }

  std::string arch;
  std::vector<std::string> dependencies;
  if (!FindArchAndLibraryDependencies(prog, &arch, &dependencies))
    return false;
  if (!dependencies.empty()) {
    AddNmfToRequestForShared(prog, arch, dependencies, req);
    return true;
  }
  // No dependencies means the main binary is statically linked.
  AddNmfToRequestForStatic(prog, arch, req);
  return true;
}

// Send a request, decode the result, and set errno on error.
static int GetInt(pp::VarDictionary dict, const char* key) {
  if (!dict.HasKey(key)) {
    return -1;
  }
  int value = dict.Get(key).AsInt();
  if (value < 0) {
    errno = -value;
    return -1;
  }
  return value;
}

static pid_t waitpid_impl(int pid, int* status, int options);

// TODO(bradnelson): Add sysconf means to query this in all libc's.
#define MAX_FILE_DESCRIPTOR 1000

static int CloneFileDescriptors(pp::VarArray* envs) {
  int fd;
  int port;

  for (fd = 0; fd < MAX_FILE_DESCRIPTOR; ++fd) {
    struct stat st;
    if (fstat(fd, &st) < 0) {
      if (errno == EBADF) {
        continue;
      }
      return -1;
    }
    port = -1;
    if (S_ISREG(st.st_mode)) {
      // TODO(bradnelson): Land nacl_io ioctl to support this.
    } else if (S_ISDIR(st.st_mode)) {
      // TODO(bradnelson): Land nacl_io ioctl to support this.
    } else if (S_ISCHR(st.st_mode)) {
      // Unsupported.
    } else if (S_ISBLK(st.st_mode)) {
      // Unsupported.
    } else if (S_ISFIFO(st.st_mode)) {
      // TODO(bradnelson): Support this once named pipe change lands.
    } else if (S_ISLNK(st.st_mode)) {
      // Unsupported.
    } else if (S_ISSOCK(st.st_mode)) {
      struct sockaddr_in addr;
      socklen_t addr_len = sizeof addr;
      if (getsockname(fd, (struct sockaddr *) &addr, &addr_len) < 0) {
        return -1;
      }
      port = ntohs(addr.sin_port);
      // TODO(bradnelson): Handle host + non-pipes.
      char entry[100];
      snprintf(entry, sizeof entry,
          "NACL_SPAWN_FD_PIPE_SOCKET=%d:%d", fd, port);
      envs->Set(envs->GetLength(), entry);
    }
  }
  return 0;
}

NACL_SPAWN_TLS jmp_buf nacl_spawn_vfork_env;
static NACL_SPAWN_TLS pid_t vfork_pid = -1;
static NACL_SPAWN_TLS int vforking = 0;

// Shared spawnve implementation. Declared static so that shared library
// overrides doesn't break calls meant to be internal to this implementation.
static int spawnve_impl(int mode, const char* path,
                        char* const argv[], char* const envp[]) {
  if (NULL == path || NULL == argv[0]) {
    errno = EINVAL;
    return -1;
  }
  if (mode == P_WAIT) {
    int pid = spawnve_impl(P_NOWAIT, path, argv, envp);
    if (pid < 0) {
      return -1;
    }
    int status;
    int result = waitpid_impl(pid, &status, 0);
    if (result < 0) {
      return -1;
    }
    return status;
  } else if (mode == P_NOWAIT || mode == P_NOWAITO) {
    // The normal case.
  } else if (mode == P_OVERLAY) {
    if (vforking) {
      vfork_pid = spawnve_impl(P_NOWAIT, path, argv, envp);
      longjmp(nacl_spawn_vfork_env, 1);
    }
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

  PSInstance* instance = PSInstance::GetInstance();
  if (!instance) {
    errno = ENOSYS;
    return -1;
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
  if (CloneFileDescriptors(&envs) < 0) {
    return -1;
  }
  req.Set("envs", envs);
  req.Set("cwd", GetCwd());

  if (!AddNmfToRequest(path, &req)) {
    errno = ENOENT;
    return -1;
  }

  return GetInt(SendRequest(&req), "pid");
}

// Spawn a new NaCl process. This is an alias for
// spawnve(mode, path, argv, NULL). Returns 0 on success. On error -1 is
// returned and errno will be set appropriately.
int spawnv(int mode, const char* path, char* const argv[]) {
  return spawnve_impl(mode, path, argv, NULL);
}

int spawnve(int mode, const char* path,
            char* const argv[], char* const envp[]) {
  return spawnve_impl(mode, path, argv, envp);
}

// Shared below by waitpid and wait.
// Done as a static so that users that replace waitpid and call wait (gcc)
// don't cause infinite recursion.
static pid_t waitpid_impl(int pid, int* status, int options) {
  pp::VarDictionary req;
  pp::VarDictionary result;
  req.Set("command", "nacl_wait");
  req.Set("pid", pid);
  req.Set("options", options);

  result = SendRequest(&req);
  int resultPid = GetInt(result, "pid");

  // WEXITSTATUS(s) is defined as ((s >> 8) & 0xff).
  if (result.HasKey("status")) {
    int rawStatus = result.Get("status").AsInt();
    *status = (rawStatus & 0xff) << 8;
  }
  return resultPid;
}

extern "C" {

#if defined(__GLIBC__)
pid_t wait(void* status) {
#else
pid_t wait(int* status) {
#endif
  return waitpid_impl(-1, static_cast<int*>(status), 0);
}

// Waits for the specified pid. The semantics of this function is as
// same as waitpid, though this implementation has some restrictions.
// Returns 0 on success. On error -1 is returned and errno will be set
// appropriately.
pid_t waitpid(pid_t pid, int* status, int options) {
  return waitpid_impl(pid, status, options);
}

// BSD wait variant with rusage.
#if defined(__BIONIC__)
pid_t wait3(int* status, int options, struct rusage* unused_rusage) {
#else
pid_t wait3(void* status, int options, struct rusage* unused_rusage) {
#endif
  return waitpid_impl(-1, static_cast<int*>(status), options);
}

// BSD wait variant with pid and rusage.
#if defined(__BIONIC__)
pid_t wait4(pid_t pid, int* status, int options,
            struct rusage* unused_rusage) {
#else
pid_t wait4(pid_t pid, void* status, int options,
            struct rusage* unused_rusage) {
#endif
  return waitpid_impl(pid, static_cast<int*>(status), options);
}

/*
 * Fake version of getpid().  This is used if there is no
 * nacl_spawn_ppid set and no IRT getpid interface available.
 */
static int getpid_fake(int* pid) {
  *pid = 1;
  return 0;
}

static struct nacl_irt_dev_getpid irt_dev_getpid;

/*
 * IRT version of getpid().  This is used if there is no
 * nacl_spawn_ppid set.
 */
static pid_t getpid_irt() {
  if (irt_dev_getpid.getpid == NULL) {
    int res = nacl_interface_query(NACL_IRT_DEV_GETPID_v0_1,
                                   &irt_dev_getpid,
                                   sizeof(irt_dev_getpid));
    if (res != sizeof(irt_dev_getpid)) {
      irt_dev_getpid.getpid = getpid_fake;
    }
  }

  int pid;
  int error = irt_dev_getpid.getpid(&pid);
  if (error != 0) {
    errno = error;
    return -1;
  }
  return pid;
}

// Get the process ID of the calling process.
pid_t getpid() {
  if (nacl_spawn_pid == -1) {
    return getpid_irt();
  }
  return nacl_spawn_pid;
}

// Get the process ID of the parent process.
pid_t getppid() {
  if (nacl_spawn_ppid == -1) {
    errno = ENOSYS;
  }
  return nacl_spawn_ppid;
}

// Spawn a process.
int posix_spawn(
    pid_t* pid, const char* path,
    const posix_spawn_file_actions_t* file_actions,
    const posix_spawnattr_t* attrp,
    char* const argv[], char* const envp[]) {
  int ret = spawnve_impl(P_NOWAIT, path, argv, envp);
  if (ret < 0) {
    return ret;
  }
  *pid = ret;
  return 0;
}

// Spawn a process using PATH to resolve.
int posix_spawnp(
    pid_t* pid, const char* file,
    const posix_spawn_file_actions_t* file_actions,
    const posix_spawnattr_t* attrp,
    char* const argv[], char* const envp[]) {
  // TODO(bradnelson): Make path expansion optional.
  return posix_spawn(pid, file, file_actions, attrp, argv, envp);
}

// Get the process group ID of the given process.
pid_t getpgid(pid_t pid) {
  pp::VarDictionary req;
  req.Set("command", "nacl_getpgid");
  req.Set("pid", pid);

  return GetInt(SendRequest(&req), "pgid");
}

// Get the process group ID of the current process. This is an alias for
// getpgid(0).
pid_t getpgrp() {
  return getpgid(0);
}

// Set the process group ID of the given process.
pid_t setpgid(pid_t pid, pid_t pgid) {
  pp::VarDictionary req;
  req.Set("command", "nacl_setpgid");
  req.Set("pid", pid);
  req.Set("pgid", pgid);

  return GetInt(SendRequest(&req), "result");
}

// Set the process group ID of the given process. This is an alias for
// setpgid(0, 0).
pid_t setpgrp() {
  return setpgid(0, 0);
}

// Get the session ID of the given process.
pid_t getsid(pid_t pid) {
  pp::VarDictionary req;
  req.Set("command", "nacl_getsid");
  req.Set("pid", pid);
  return GetInt(SendRequest(&req), "sid");
}

// Make the current process a session leader.
pid_t setsid() {
  pp::VarDictionary req;
  req.Set("command", "nacl_setsid");
  return GetInt(SendRequest(&req), "sid");
}

void jseval(const char* cmd, char** data, size_t* len) {
  pp::VarDictionary req;
  req.Set("command", "nacl_jseval");
  req.Set("cmd", cmd);
  pp::VarDictionary result = SendRequest(&req);
  std::string result_str = result.Get("result").AsString();
  if (len) {
    *len = result_str.size();
  }
  if (data) {
    *data = static_cast<char*>(malloc(result_str.size() + 1));
    assert(*data);
    memcpy(*data, result_str.data(), result_str.size());
    (*data)[result_str.size()] = '\0';
  }
}

// This is the address for localhost (127.0.0.1).
#define LOCAL_HOST 0x7F000001

// Connect to a port on localhost and return the socket.
static int TCPConnectToLocalhost(int port) {
  int sockfd;
  struct sockaddr_in addr;

  memset(&addr, 0, sizeof addr);
  addr.sin_family = AF_INET;
  addr.sin_port = htons(port);
  addr.sin_addr.s_addr = htonl(LOCAL_HOST);

  sockfd = socket(AF_INET, SOCK_STREAM, 0);
  if (sockfd < 0) {
    return -1;
  }

  if (connect(sockfd, (struct sockaddr*)&addr, sizeof addr) < 0) {
    close(sockfd);
    return -1;
  }

  return sockfd;
}

// Create a pipe. pipefd[0] will be the read end of the pipe and pipefd[1] the
// write end of the pipe.
int pipe(int pipefd[2]) {
  PSInstance* instance = PSInstance::GetInstance();
  if (!instance)
    return ENOSYS;

  pp::VarDictionary req, result;
  int readPort, writePort, readSocket, writeSocket;

  if (pipefd == NULL) {
    errno = EFAULT;
    return -1;
  }

  req.Set("command", "nacl_pipe");
  result = SendRequest(&req);
  readPort = GetInt(result, "read");
  writePort = GetInt(result, "write");
  if (readPort == -1 || writePort == -1) {
    return -1;
  }

  readSocket = TCPConnectToLocalhost(readPort);
  writeSocket = TCPConnectToLocalhost(writePort);
  if (readSocket < 0 || writeSocket < 0) {
    if (readSocket >= 0) {
      close(readSocket);
    }
    if (writeSocket >= 0) {
      close(writeSocket);
    }
    return -1;
  }

  pipefd[0] = readSocket;
  pipefd[1] = writeSocket;

  return 0;
}

void nacl_spawn_vfork_before(void) {
  assert(!vforking);
  vforking = 1;
}

pid_t nacl_spawn_vfork_after(int jmping) {
  if (jmping) {
    vforking = 0;
    return vfork_pid;
  }
  return 0;
}

void nacl_spawn_vfork_exit(int status) {
  if (vforking) {
    pp::VarDictionary req;
    req.Set("command", "nacl_deadpid");
    req.Set("status", status);
    int result = GetInt(SendRequest(&req), "pid");
    if (result < 0) {
      errno = -result;
      vfork_pid = -1;
    } else {
      vfork_pid = result;
    }
    longjmp(nacl_spawn_vfork_env, 1);
  } else {
    _exit(status);
  }
}

#define VARG_TO_ARGV_START \
  va_list vl; \
  va_start(vl, arg); \
  va_list vl_count; \
  va_copy(vl_count, vl); \
  int count = 1; \
  while (va_arg(vl_count, char*)) { \
    ++count; \
  } \
  va_end(vl_count); \
  /* Copying all the args into argv plus a trailing NULL */ \
  char** argv = static_cast<char**>(alloca(sizeof(char *) * (count + 1))); \
  argv[0] = const_cast<char*>(arg); \
  for (int i = 1; i <= count; i++) { \
    argv[i] = va_arg(vl, char*); \
  }

#define VARG_TO_ARGV \
  VARG_TO_ARGV_START; \
  va_end(vl);

#define VARG_TO_ARGV_ENVP \
  VARG_TO_ARGV_START; \
  char* const* envp = va_arg(vl, char* const*); \
  va_end(vl);

int execve(const char *filename, char *const argv[], char *const envp[]) {
  return spawnve_impl(P_OVERLAY, filename, argv, envp);
}

int execv(const char *path, char *const argv[]) {
  return spawnve_impl(P_OVERLAY, path, argv, environ);
}

int execvp(const char *file, char *const argv[]) {
  // TODO(bradnelson): Limit path resolution to 'p' variants.
  return spawnve_impl(P_OVERLAY, file, argv, environ);
}

int execvpe(const char *file, char *const argv[], char *const envp[]) {
  // TODO(bradnelson): Limit path resolution to 'p' variants.
  return spawnve_impl(P_OVERLAY, file, argv, envp);
}

int execl(const char *path, const char *arg, ...) {
  VARG_TO_ARGV;
  return spawnve_impl(P_OVERLAY, path, argv, environ);
}

int execlp(const char *file, const char *arg, ...) {
  VARG_TO_ARGV;
  // TODO(bradnelson): Limit path resolution to 'p' variants.
  return spawnve_impl(P_OVERLAY, file, argv, environ);
}

int execle(const char *path, const char *arg, ...) {  /* char* const envp[] */
  VARG_TO_ARGV_ENVP;
  return spawnve_impl(P_OVERLAY, path, argv, envp);
}

int execlpe(const char *path, const char *arg, ...) {  /* char* const envp[] */
  VARG_TO_ARGV_ENVP;
  // TODO(bradnelson): Limit path resolution to 'p' variants.
  return spawnve_impl(P_OVERLAY, path, argv, envp);
}

};  // extern "C"
