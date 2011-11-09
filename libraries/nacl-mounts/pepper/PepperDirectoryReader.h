#ifndef PACKAGES_LIBRARIES_NACL_MOUNTS_PEPPER_PEPPERDIRECTORYREADER_H_
#define PACKAGES_LIBRARIES_NACL_MOUNTS_PEPPER_PEPPERDIRECTORYREADER_H_

class DirectoryReader {
 public:
  virtual int ReadDirectory(const std::string& path,
      std::set<std::string>* entries, const pp::CompletionCallback& cc) = 0;
};

#endif // PACKAGES_LIBRARIES_NACL_MOUNTS_PEPPER_PEPPERDIRECTORYREADER_H_
