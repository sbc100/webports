#include "nacl_file.h"

#include <errno.h>
#include <cstdio>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>
#include <errno.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <pthread.h>

#include <tr1/functional>

#include "geturl_handler.h"
#include "nacl/nacl_inttypes.h"

extern "C" {
int __wrap_open(const char* pathname, int mode, int perms);
int __wrap_close(int dd);
int __wrap_read(int, void*, size_t);
off_t __wrap_lseek(int, off_t, int);
int nacl_file_write(int, void*, size_t);
int nacl_file_length(int fd);
}

namespace {
  std::string StripPath(const std::string& file_name) {
    if ((file_name.length() > 2) && (file_name.substr(0,2) == "./")) {
      return file_name.substr(2);
    }
    return file_name;
  }
}

// NOTE:  HACK:  None of this is thread-safe.  The idea is that all files must
// be completely downloaded before they are accessed, so there is no thread
// contention.
namespace nacl_file {

File::File(const std::string& name_arg, std::vector<uint8_t>& data_arg)
    : name(StripPath(name_arg)) {
  data.swap(data_arg);
  //std::printf("Created 'File' for %s, data is %zd bytes.\n", name.c_str(), data.size());
}

int FileHandle::Read(void* buffer, size_t num_bytes) {
  //std::printf("Attempting read of %s, position %zd, size %zd, %zd bytes.\n", file->name.c_str(), position, file->data.size(), num_bytes);
  if (position == file->data.size()) {
    //std::printf("Returning 0; EOF.\n");
    return 0;  // EOF
  }
  int bytes_to_read(std::min(num_bytes, file->data.size() - position));
  memcpy(buffer, &file->data[position], bytes_to_read);
  position += bytes_to_read;
  //std::printf("Read %zd bytes successfully, setting position to %zd.\n", bytes_to_read, position);
  return bytes_to_read;
}

// WARNING, Write is pretty much untested and probably doesn't work.
int FileHandle::Write(void* buffer, size_t num_bytes) {
  //std::printf("Attempting write of %s, position %zd, size %zd, %zd bytes.\n", file->name.c_str(), position, file->data.size(), num_bytes);
  if (position + num_bytes > file->data.size()) {
    file->data.resize(position + num_bytes);
  }
  memcpy(&file->data[position], buffer, num_bytes);
  position += num_bytes;
  //std::printf("Wrote %zd bytes successfully, setting position to %zd.\n", num_bytes, position);
  return 0;
}

off_t FileHandle::Seek(off_t offset, int whence) {
  //std::printf("Seeking from %zd with offset %ld, size=%zd, whence=", position, static_cast<long>(offset), file->data.size());
  switch (whence) {
    case SEEK_SET:
      //std::printf("SEEK_SET");
      position = offset;
      break;
    case SEEK_CUR:
      //std::printf("SEEK_CUR");
      position += offset;
      break;
    case SEEK_END:
      //std::printf("SEEK_END");
      position = static_cast<off_t>(file->data.size()) - offset - 1;
      break;
    default:
      break;
  }
  //std::printf("\nNew position is %zd.\n", position);
  return position;
}

FileManager::FileManager()
    : last_fd_(2) { // start with empty spots for stdout, stdin, and stderr
  //std::printf("Constructing FileManager.\n");
}
FileManager::~FileManager() {}
void FileManager::FileFinished(const std::string& file_name_arg,
                               std::vector<uint8_t>& data) {
  std::string name = StripPath(file_name_arg);
  file_map_[name] = File(name, data);
  pending_files_.erase(name);
  if (pending_files_.empty()) {
    ready_func_();
  }
}

FileManager::ResponseHandler::ResponseHandler(const std::string& name_arg,
                                              FileManager* manager_arg)
      : name_(StripPath(name_arg)), manager_(manager_arg) {
  //std::printf("Creating ResponseHandler.\n");
}

void FileManager::ResponseHandler::FileFinished(std::vector<uint8_t>& data,
                                                int32_t error) {
  //std::printf("Finished downloading %s, %zd bytes, error: %"NACL_PRId32".\n", name_.c_str(), data.size(), error);
  manager_->FileFinished(StripPath(name_), data);
  // NOTE:  manager_ deletes us in FileFinished, so |this| is no longer
  //        valid here.
}

FileManager& FileManager::instance() {
  static FileManager file_manager_instance;
  return file_manager_instance;
}

void FileManager::Fetch(const std::string& file_name_arg,
                        size_t size) {
  //std::printf("Requesting %s\n", file_name_arg.c_str());
  std::string file_name = StripPath(file_name_arg);
  FileManager& self = instance();
  std::pair<PendingMap::iterator, bool> iter_success_pair;
  iter_success_pair = self.pending_files_.insert(
      PendingMap::value_type(file_name,
                             ResponseHandler(file_name, &self)));
  PendingMap::iterator iter = iter_success_pair.first;
  bool success = iter_success_pair.second;
  // If it was successful, then this is the first time the file has been
  // added, and we should start a URL request.
  if (success) {
    GetURLHandler* handler = GetURLHandler::Create(self.pp_instance_,
                                                   file_name,
                                                   size);
    if (!handler->Start(NewGetURLCallback(&iter->second,
                                          &ResponseHandler::FileFinished))) {
      // Private destructor;  can't follow the example.
      // delete handler;
    }
  }
}

int FileManager::GetFD(const std::string& file_name_arg) {
  FileManager& self(instance());
  std::string file_name(StripPath(file_name_arg));
  FileMap::iterator iter = self.file_map_.find(file_name);
  if (iter != self.file_map_.end()) {
    // TODO(dmichael) worry about duplicates and overflow.
    int fd = ++self.last_fd_;
    self.file_handle_map_[fd] = FileHandle(&iter->second);
    return fd;
  }
  //std::printf("ERROR file not found, %s.\n", file_name_arg.c_str());
  errno = ENOENT;
  return -1;
}

void FileManager::AddEmptyFile(const std::string& file_name_arg) {
  FileManager& self(instance());
  std::string file_name(StripPath(file_name_arg));
  std::vector<uint8_t> empty_vec;
  self.file_map_.insert(FileMap::value_type(file_name,
                                            File(file_name, empty_vec)));
}

void FileManager::Close(int fd) {
  instance().file_handle_map_.erase(fd);
}

FileHandle* FileManager::GetFileHandle(int fd) {
  //std::printf("Getting file for FD %d.\n", fd);
  FileManager& self(instance());
  FileHandleMap::iterator iter = self.file_handle_map_.find(fd);
  if (iter != self.file_handle_map_.end())
    return &iter->second;

  return NULL;
}

}  // namespace nacl_file

int __wrap_open(char const *pathname, int oflags, int perms) {
  //std::printf("nacl_open, file %s\n", pathname);
  if (oflags & O_WRONLY) {
    // TODO: Make appending fail if append flag is not provided.
    //std::printf("Write mode.\n");
    // AddEmptyFile will do nothing if the file already exists.
    nacl_file::FileManager::AddEmptyFile(StripPath(pathname));
  }
  int fd = nacl_file::FileManager::GetFD(StripPath(pathname));
  //std::printf("Returning %d\n", fd);
  return fd;
}

int __wrap_close(int fd) {
  //std::printf("nacl_close, fd %d\n", fd);
  nacl_file::FileManager::Close(fd);
  return 0;
}

int __wrap_read(int fd, void* buffer, size_t num_bytes) {
  //std::printf("nacl_read, fd %d, num_bytes %zd\n", fd, num_bytes);
  nacl_file::FileHandle* file = nacl_file::FileManager::GetFileHandle(fd);
  if (file) {
    return file->Read(buffer, num_bytes);
  }
  //std::printf("No file found for fd %d.\n", fd);
  errno = ENOENT;
  return -1;
}

int nacl_file_write(int fd, void* buffer, size_t num_bytes) {
  //std::printf("nacl_file_write, fd %d, num_bytes %zd\n", fd, num_bytes);
  nacl_file::FileHandle* file = nacl_file::FileManager::GetFileHandle(fd);
  if (file) {
    return file->Write(buffer, num_bytes);
  }
  //std::printf("No file found for fd %d.\n", fd);
  errno = ENOENT;
  return -1;
}


off_t __wrap_lseek(int fd, off_t offset, int whence) {
  //std::printf("__wrap_seek, fd %d\n", fd);
  nacl_file::FileHandle* file = nacl_file::FileManager::GetFileHandle(fd);
  if (file) {
    return file->Seek(offset, whence);
  }
  errno = ENOENT;
  return -1;
}

int nacl_file_length(int fd) {
  //std::printf("__wrap_length, fd %d\n", fd);
  nacl_file::FileHandle* handle = nacl_file::FileManager::GetFileHandle(fd);
  if (handle) {
    int size = static_cast<int>(handle->file->data.size());
    //std::printf("__wrap_length is %d\n", size);
    return size;
  }
  errno = ENOENT;
  return -1;
}

