// Copyright 2010 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.
#include "examples/scriptable/crypto/aes_codec.h"
#include <string.h>
#include <stdlib.h>
#include <tomcrypt.h>

namespace {
const int kBlockSize = 16;
const int kKeySize   = 32;
const int kSaltSize  = kBlockSize;
const int kTagSize   = kBlockSize;
const int kPKCSIterationCounter = 1000;
const int kSHA256ResultSize = 32;
const int kTomCryptError = -1;

bool CreateSaltKeyAndInitializationVector(
    const char* password,
    unsigned char salt[kSaltSize],
    unsigned char key[kKeySize],
    unsigned char initialization_vector[kBlockSize]);

bool CreateKeyAndInitializationVector(
    const char* password,
    const unsigned char salt[kSaltSize],
    unsigned char key[kKeySize],
    unsigned char initialization_vector[kBlockSize]);
}  // namespace

void* AESCodec::Encode(const void* plain_text,
                       int plain_text_sz,
                       const char* password,
                       int* encoded_text_sz) {
  // Encrypted message has one block with (random) salt,
  // block with message authentication code (aka MAC, aka tag),
  // and cipher text (same size as plain text).
  if ((NULL == plain_text) ||
      (0 == plain_text_sz) ||
      (NULL == password) ||
      (0 == encoded_text_sz))
    return NULL;

  *encoded_text_sz = 0;
  // Function |register_cipher| is provided by the tomcrypt API.
  int result = register_cipher(&aes_desc);
  if (CRYPT_OK != result)
    return NULL;

  // Function |find_cipher| is provided by the tomcrypt API.
  int aes_id = find_cipher(aes_desc.name);
  // eax_encrypt_authenticate_memory() crashes if called
  // with cipher id equal -1.
  if (kTomCryptError == aes_id)
    return NULL;

  if (plain_text_sz > (INT_MAX - kSaltSize - kTagSize))
    return NULL;  // Integer overflow.
  int out_sz = kSaltSize + kTagSize + plain_text_sz;

  void* encoded_text = malloc(out_sz);
  if (NULL == encoded_text)
    return NULL;

  unsigned char* salt = static_cast<unsigned char*>(encoded_text);
  unsigned char key[kKeySize];
  unsigned char iv[kBlockSize];
  if (!CreateSaltKeyAndInitializationVector(password, salt, key, iv)) {
    free(encoded_text);
    return NULL;
  }
  unsigned char* tag = salt + kSaltSize;
  uint32_t tag_sz = kTagSize;
  unsigned char* cp = tag + tag_sz;
  const unsigned char* pt = static_cast<const unsigned char*>(plain_text);

  // Function |eax_encrypt_authenticate_memory| is provided by the tomcrypt API.
  result = eax_encrypt_authenticate_memory(
      aes_id,  // cipher id
      key, sizeof(key),
      iv, sizeof(iv),  // initialization vector
      NULL, 0,    // no header
      pt, plain_text_sz,
      cp,         // ciphertext goes here
      tag, &tag_sz);
  memset(key, 0, sizeof(key));  // zero-out sensetive information

  if (CRYPT_OK != result) {
    free(encoded_text);
    encoded_text = NULL;
  } else {
    *encoded_text_sz = out_sz;
  }
  return encoded_text;
}

void* AESCodec::Decode(const void* encoded_text,
                       int encoded_text_sz,
                       const char* password,
                       int* plain_text_sz) {
  // Encrypted message has one block with (random) salt,
  // block with message authentication code (aka MAC, aka tag),
  // and cipher text (same size as plain text).
  if ((encoded_text_sz <= (kSaltSize + kTagSize)) || (NULL == encoded_text))
    return NULL;
  if ((NULL == password) || (0 == plain_text_sz))
    return NULL;

  // Function |register_cipher| is provided by the tomcrypt API.
  int result = register_cipher(&aes_desc);
  if (CRYPT_OK != result)
    return NULL;

  // Function |find_cipher| is provided by the tomcrypt API.
  int aes_id = find_cipher(aes_desc.name);
  // eax_decrypt_verify_memory() crashes if called
  // with cipher id equal -1.
  if (kTomCryptError == aes_id)
    return NULL;

  const unsigned char* salt = static_cast<const unsigned char*>(encoded_text);
  unsigned char key[kKeySize];
  unsigned char iv[kBlockSize];
  if (!CreateKeyAndInitializationVector(password, salt, key, iv))
    return NULL;

  *plain_text_sz = encoded_text_sz - kSaltSize - kTagSize;
  unsigned char* plain_text =
      static_cast<unsigned char*>(malloc(*plain_text_sz));
  if (NULL == plain_text) {
    *plain_text_sz = 0;
    return NULL;
  }
  unsigned char* tag = const_cast<unsigned char*>(salt) + kSaltSize;
  uint32_t tag_sz = kTagSize;
  unsigned char* cp = tag + tag_sz;
  uint32_t cp_sz = *plain_text_sz;

  // Function |eax_decrypt_verify_memory| is provided by the tomcrypt API.
  int tag_is_valid = 0;
  result = eax_decrypt_verify_memory(
      aes_id,  // cipher id
      key, sizeof(key),
      iv, sizeof(iv),  // initialization vector
      NULL, 0,    // no header
      cp, cp_sz,  // ciphertext
      plain_text,
      tag, tag_sz,
      &tag_is_valid);
  memset(key, 0, sizeof(key));  // zero-out sensetive information

  if ((CRYPT_OK != result) || (0 == tag_is_valid)) {
    free(plain_text);
    plain_text = 0;
    *plain_text_sz = 0;
  }
  return plain_text;
}

bool AESCodec::SelfTest() {
  const char* password = "password";
  const char* plain_text = "unsigned char* tag = const_cast<unsigned char*>(i";
  int plain_text_sz = strlen(plain_text) + 1;

  int encoded_text_sz = 0;
  void* encoded_text = Encode(plain_text,
                              plain_text_sz,
                              password,
                              &encoded_text_sz);
  if ((NULL == encoded_text) || (0 == encoded_text_sz))
    return false;

  if (encoded_text_sz != (plain_text_sz + (2 * kBlockSize))) {
    free(encoded_text);
    return false;
  }
  int decripted_text_sz = 0;
  void* decripted_text = Decode(encoded_text,
                                encoded_text_sz,
                                password,
                                &decripted_text_sz);
  free(encoded_text);
  if ((NULL == decripted_text) || (0 == decripted_text_sz))
    return false;

  if (decripted_text_sz != plain_text_sz)
    return false;

  if (memcmp(decripted_text, plain_text, plain_text_sz)) {
    free(decripted_text);
    return false;
  }
  free(decripted_text);
  return true;
}

namespace {
bool CreateSaltKeyAndInitializationVector(
    const char* password,
    unsigned char salt[kSaltSize],
    unsigned char key[kKeySize],
    unsigned char initialization_vector[kBlockSize]) {
  // Function |rng_get_bytes| gets |kSaltSize| random bytes, needed to create
  // session key and initialization vector.
  // Function |rng_get_bytes| is provided by the tomcrypt API.
  rng_get_bytes(salt, kSaltSize, 0);

  // Put salt through hash, so that no RNG state can leak outside.
  // Functions |sha256_init|, |sha256_process| and |sha256_done| are provided
  // by the tomcrypt API.
  unsigned char hash_result[kSHA256ResultSize];
  hash_state hs;
  sha256_init(&hs);
  sha256_process(&hs, salt, kSaltSize);
  sha256_done(&hs, hash_result);
  memcpy(salt, hash_result, kSaltSize);

  return CreateKeyAndInitializationVector(
      password,
      salt,
      key,
      initialization_vector);
}

bool CreateKeyAndInitializationVector(
    const char* password,
    const unsigned char salt[kSaltSize],
    unsigned char key[kKeySize],
    unsigned char initialization_vector[kBlockSize]) {
  // Function |register_hash| is provided by the tomcrypt API.
  if (register_hash(&sha256_desc) == kTomCryptError)
    return false;
  // Function |find_hash| is provided by the tomcrypt API.
  int hash_id = find_hash(sha256_desc.name);
  if (kTomCryptError == hash_id)
    return false;

  unsigned char out_buff[kKeySize + kBlockSize];
  uint32_t out_buff_sz = sizeof(out_buff);
  uint32_t password_sz = strlen((const char*)password);

  // Function |pkcs_5_alg2| is provided by the tomcrypt API.
  uint32_t res = pkcs_5_alg2(reinterpret_cast<const unsigned char*>(password),
                             password_sz,
                             salt, kSaltSize,
                             kPKCSIterationCounter,
                             hash_id,
                             out_buff, &out_buff_sz);
  if (CRYPT_OK == res) {
    memcpy(key, out_buff, kKeySize);
    memcpy(initialization_vector, out_buff + kKeySize,
           kBlockSize);
    return true;
  }
  return false;
}
}
