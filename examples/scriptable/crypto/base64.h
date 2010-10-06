// Copyright 2010 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.
#ifndef EXAMPLES_SCRIPTABLE_CRYPTO_BASE64_H_
#define EXAMPLES_SCRIPTABLE_CRYPTO_BASE64_H_

class Base64 {
 public:
  Base64();

  // Memory for the encoded text/binary is obtained with malloc(), and
  // shall be freed with free().
  char* ConvertBinToText(const void* in, int in_sz) const;
  void* ConvertTextToBin(const char* in, int* out_sz) const;
  static bool SelfTest();

  void set_max_line_length(int len);
  void set_line_delimiter(const char* str);

 protected:
  int max_line_length_;
  const char* line_delimiter_;
};
#endif  // EXAMPLES_SCRIPTABLE_CRYPTO_BASE64_H_

