// Copyright 2008 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#include <nacl/nacl_npapi.h>
#include <nacl/nacl_srpc.h>
#include <sys/time.h>
#include <sys/times.h>
#include <tomcrypt.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

#include "examples/scriptable/crypto/aes_codec.h"
#include "examples/scriptable/crypto/base64.h"
#include "examples/scriptable/crypto/scriptable_aes_codec.h"

namespace {
// Converts |value| to a NPVariant and sets the |result|
// to that value.  This is used for returning a string
// from C++ back to Javascript
void SetReturnStringVal(NPVariant* result, const std::string& value) {
  unsigned int msg_length = strlen(value.c_str()) + 1;
  char *msg_copy = static_cast<char*>(NPN_MemAlloc(msg_length));
  // Note: |msg_copy| will be freed later on by the browser, so it needs to
  // be allocated here with NPN_MemAlloc().
  strncpy(msg_copy, value.c_str(), msg_length);
  STRINGN_TO_NPVARIANT(msg_copy, msg_length - 1, *result);
}

// Memory for the new string is obtained with malloc(), and shall
// be freed with free(). Returns NULL on failure.
char* NPVariantToString(const NPVariant& var) {
  if (NPVariantType_String != var.type)
    return  NULL;
  size_t len = var.value.stringValue.UTF8Length;
  char* str = static_cast<char*>(malloc(len + 1));
  if (NULL != str) {
    memcpy(str, var.value.stringValue.UTF8Characters, len);
    str[len] = 0;
  }
  return str;
}
}  // namespace

// constructor for the ScriptableAESCodec class
ScriptableAESCodec::ScriptableAESCodec()
    : Scriptable() {
  printf("ScriptableAESCodec::ScriptableAESCodec() was called!\n");
  fflush(stdout);
}

// destructor for the ScriptableAESCodec class
ScriptableAESCodec::~ScriptableAESCodec() {
  printf("ScriptableAESCodec::~ScriptableAESCodec() was called!\n");
  fflush(stdout);
}

bool ScriptableAESCodec::Encrypt(Scriptable* instance,
                                 const NPVariant* args,
                                 uint32_t arg_count,
                                 NPVariant* result) {
  printf("ScriptableAESCodec::Encrypt() was called!\n");
  instance = instance;
  if (arg_count < 2) {
    SetReturnStringVal(result, "Error in Encrypt, arg_count too small");
    return true;
  }
  if ((NPVariantType_String != args[0].type) ||
       (NPVariantType_String != args[1].type)) {
    SetReturnStringVal(result, "Error in Encrypt, args are not strings");
    return true;
  }
  SetReturnStringVal(result, "");
  char* pwd = NPVariantToString(args[0]);
  if (NULL == pwd) {
    SetReturnStringVal(result, "Error in Encrypt, memory allocation failed");
    return true;
  }
  char* plain_text = NPVariantToString(args[1]);
  if (NULL == plain_text) {
    free(pwd);
    SetReturnStringVal(result, "Error in Encrypt, memory allocation failed");
    return true;
  }
  int encoded_text_sz = 0;
  void* encoded_text = AESCodec::Encode(plain_text, strlen(plain_text) + 1,
                                        pwd, &encoded_text_sz);
  memset(pwd, 0, strlen(pwd));
  free(pwd);
  free(plain_text);
  if (NULL == encoded_text) {
    SetReturnStringVal(result, "Error in Encrypt, encryption failed");
    return true;
  }
  Base64 base64;
  char* base64_text = base64.ConvertBinToText(encoded_text, encoded_text_sz);
  free(encoded_text);

  if (NULL == base64_text) {
    SetReturnStringVal(result, "Error in Encrypt, base64 encoding failed");
    return true;
  }
  SetReturnStringVal(result, base64_text);
  free(base64_text);
  return true;
}

bool ScriptableAESCodec::Decrypt(Scriptable * instance,
                                const NPVariant* args,
                                uint32_t arg_count,
                                NPVariant* result) {
  printf("ScriptableAESCodec::Decrypt() was called!\n");
  instance = instance;
  if (arg_count < 2) {
    SetReturnStringVal(result, "Error in Decrypt, arg_count too small");
    return true;
  }
  if ((NPVariantType_String != args[0].type) ||
       (NPVariantType_String != args[1].type)) {
    SetReturnStringVal(result, "Error in Decrypt, args are not strings");
    return true;
  }
  char* pwd = NPVariantToString(args[0]);
  if (NULL == pwd) {
    SetReturnStringVal(result, "Error in Decrypt, memory allocation failed");
    return true;
  }
  char* encoded_text = NPVariantToString(args[1]);
  if (NULL == encoded_text) {
    free(pwd);
    SetReturnStringVal(result, "Error in Decrypt, memory allocation failed");
    return true;
  }
  int cipher_text_sz = 0;
  Base64 base64;
  void* cipher_text = base64.ConvertTextToBin(encoded_text, &cipher_text_sz);
  free(encoded_text);
  if (NULL != cipher_text) {
    int plain_text_sz = 0;
    void* plain_text = AESCodec::Decode(cipher_text, cipher_text_sz,
                                        pwd,
                                        &plain_text_sz);
    memset(pwd, 0, strlen(pwd));  // zero-out sensetive information
    free(pwd);
    free(cipher_text);
    if (NULL != plain_text) {
      SetReturnStringVal(result, static_cast<char*>(plain_text));
      free(plain_text);
    }
  }
  return true;
}

// Put the methods that are callable by Javascript into the method table
void ScriptableAESCodec::InitializeMethodTable() {
  printf("ScriptableIdeaCodec::InitializeMethodTable() was called!\n");
  fflush(stdout);
  NPIdentifier decrypt_id = NPN_GetStringIdentifier("Decrypt");
  IdentifierToMethodMap::value_type decrypt_method(decrypt_id,
    &ScriptableAESCodec::Decrypt);
  method_table_->insert(decrypt_method);

  NPIdentifier encrypt_id = NPN_GetStringIdentifier("Encrypt");
  IdentifierToMethodMap::value_type encrypt_method(encrypt_id,
    &ScriptableAESCodec::Encrypt);
  method_table_->insert(encrypt_method);
}

// Had to write stubs of some missing c runtime functions.
// I will remove them once SDK is fixed.
extern "C" {
clock_t times(struct tms* buffer) {
  clock_t ticks = 0;
  struct timeval time_val;
  if (gettimeofday(&time_val, NULL) == 0) {
    ticks = (time_val.tv_sec * CLOCKS_PER_SEC) +
        ((CLOCKS_PER_SEC * time_val.tv_usec) / 1000000);
  }
  buffer->tms_utime = ticks;  // User CPU time.
  buffer->tms_stime = ticks;  // System CPU time.
  buffer->tms_cutime = 0;     // User CPU time of dead children.
  buffer->tms_cstime = 0;     // System CPU time of dead children.
  return ticks;
}

int kill(pid_t pid, int sig) {
  return 0;
}
}  // extern "C"
