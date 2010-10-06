// Copyright 2010 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.
#include "examples/scriptable/crypto/base64.h"
#include <malloc.h>
#include <tomcrypt.h>

namespace {
const int kDefaultLineLength = 76;
const char* kDefaultLineDelimiter = "\r\n";
const int kMinLineLength = 16;
const size_t kMaxDelimiterSz = kMinLineLength / 3;
const int kTomCryptError = -1;
}  // namespace

Base64::Base64() : max_line_length_(kDefaultLineLength),
  line_delimiter_(kDefaultLineDelimiter) {
}

void Base64::set_max_line_length(int len) {
  max_line_length_ = (len > kMinLineLength) ? len : kMinLineLength;
}

void Base64::set_line_delimiter(const char* str) {
  if ((NULL != str) && (strlen(str) < kMaxDelimiterSz))
    line_delimiter_ = str;
}

char* Base64::ConvertBinToText(const void* in, int in_sz) const {
  if ((NULL == in) || (0 == in_sz))
    return NULL;

  // Gets the buffer size needed.
  unsigned char tmp[2];
  uint32_t char_num_tmp = 0;
  // Function |base64_encode| is provided by the tomcrypt API.
  base64_encode(
    static_cast<const unsigned char*>(in),
    in_sz,
    tmp,
    &char_num_tmp);

  if (char_num_tmp > INT_MAX)
    return NULL;  // Integer overflow.
  int char_num = static_cast<int>(char_num_tmp);

  const char* line_delimiter = line_delimiter_;
  if (kMaxDelimiterSz < strlen(line_delimiter))
    line_delimiter = kDefaultLineDelimiter;
  int line_delimiter_sz = strlen(line_delimiter);

  int max_line_length =
      max_line_length_ > kMinLineLength ? max_line_length_ : kMinLineLength;
  int num_of_lines = char_num / max_line_length;
  if (num_of_lines > (INT_MAX / line_delimiter_sz))
    return NULL;  // Integer overflow.
  int total_delimiter_sz = num_of_lines * line_delimiter_sz;

  if (char_num > (INT_MAX - total_delimiter_sz))
    return NULL;  // Integer overflow.
  int out_sz = char_num + total_delimiter_sz;
  if (out_sz > (INT_MAX - 1))
    return NULL;  // Integer overflow.
  out_sz++;

  unsigned char* out = static_cast<unsigned char*>(malloc(out_sz));
  if (NULL == out)
    return NULL;

  unsigned char* base64_no_linebreaks =
      static_cast<unsigned char*>(malloc(char_num));
  if (NULL == base64_no_linebreaks) {
    free(out);
    return NULL;
  }
  // Function |base64_encode| is provided by the tomcrypt API.
  base64_encode(
      static_cast<const unsigned char*>(in),
      in_sz,
      base64_no_linebreaks,
      &char_num_tmp);

  int pos_in_line = 0;
  int pos_in_out = 0;
  for (int i = 0; i < char_num; i++) {
    out[pos_in_out++] = base64_no_linebreaks[i];
    pos_in_line++;
    if (pos_in_line >= max_line_length) {
      pos_in_line = 0;
      for (int k = 0; k < line_delimiter_sz; k++)
        out[pos_in_out++] = line_delimiter_[k];
    }
  }
  out[pos_in_out++] = 0;
  assert(pos_in_out <= out_sz);
  free(base64_no_linebreaks);
  return reinterpret_cast<char*>(out);
}

void* Base64::ConvertTextToBin(const char* in, int* out_sz) const {
  if ((NULL == in) || (0 == out_sz))
    return NULL;

  *out_sz = 0;
  size_t in_sz = strlen(in);
  size_t out_len_tmp = (in_sz / 4) * 3;
  if (out_len_tmp > INT_MAX)
    return NULL;  // Integer overflow.
  int out_len = out_len_tmp;

  void* out = malloc(out_len);
  if (out) {
    uint32_t out_len_tmp = out_len;
    // Function |base64_decode| is provided by the tomcrypt API.
    int res = base64_decode(reinterpret_cast<const unsigned char*>(in), in_sz,
                            static_cast<unsigned char*>(out), &out_len_tmp);
    out_len = out_len_tmp;
    if (CRYPT_OK != res) {
      free(out);
      out = NULL;
    } else {
      *out_sz = out_len;
    }
  }
  return out;
}

bool  Base64::SelfTest() {
  char bin[100];
  for (size_t i = 0; i < sizeof(bin); i++)
    bin[i] = i;

  Base64 base64;
  char* encoded = base64.ConvertBinToText(bin, sizeof(bin));
  if (NULL == encoded)
    return false;

  if (strlen(encoded) < 100)
    return false;

  int decoded_sz = 0;
  void* decoded = base64.ConvertTextToBin(encoded, &decoded_sz);
  free(encoded);
  if (NULL == decoded)
    return false;

  if (decoded_sz != sizeof(bin)) {
    free(decoded);
    return false;
  }

  if (memcmp(bin, decoded, sizeof(bin)) != 0) {
    free(decoded);
    return false;
  }

  free(decoded);
  return true;
}
