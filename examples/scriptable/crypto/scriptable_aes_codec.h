// Copyright 2010 The Native Client SDK Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can
// be found in the LICENSE file.

#ifndef EXAMPLES_SCRIPTABLE_CRYPTO_SCRIPTABLE_AES_CODEC_H_
#define EXAMPLES_SCRIPTABLE_CRYPTO_SCRIPTABLE_AES_CODEC_H_

#include <string>
#include "examples/scriptable/crypto/scriptable.h"

// Extends Scriptable and adds the plugin's specific functionality.
class ScriptableAESCodec : public Scriptable {
 public:
  ScriptableAESCodec();
  virtual ~ScriptableAESCodec();

  // Called by JavaScript -- this is a static method to decrypt the text
  // JS: plain_text = aesCodec.Decrypt(pwd,cipher_text);
  static bool Decrypt(Scriptable* instance,
                      const NPVariant* args,
                      uint32_t arg_count,
                      NPVariant* result);

  // Called by JavaScript -- this is a static method to encrypt the text
  // JS: cipher_text = aesCodec.Encrypt(pwd,plain_text);
  static bool Encrypt(Scriptable* instance,
                      const NPVariant* args,
                      uint32_t arg_count,
                      NPVariant* result);

 private:
  // Populates the method table with our specific interface.
  virtual void InitializeMethodTable();
  // Populates the propert table with our specific interface.
  // Since this class has no visible properties the function does nothing.
  virtual void InitializePropertyTable() {}
};

#endif  // EXAMPLES_SCRIPTABLE_CRYPTO_SCRIPTABLE_AES_CODEC_H_

