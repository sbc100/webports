/*
 * Copyright (c) 2012 The Native Client Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include <cstdio>
#include <cstring>
#include <pthread.h>
#include <unistd.h>

// Pepper includes
#include "ppapi/c/pp_bool.h"
#include "ppapi/c/pp_errors.h"
#include "ppapi/cpp/audio.h"
#include "ppapi/cpp/completion_callback.h"
#include "ppapi/cpp/graphics_2d.h"
#include "ppapi/cpp/image_data.h"
#include "ppapi/cpp/input_event.h"
#include "ppapi/cpp/instance.h"
#include "ppapi/cpp/module.h"
#include "ppapi/cpp/rect.h"
#include "ppapi/cpp/size.h"
#include "ppapi/cpp/var_array_buffer.h"

#include "nacl-mounts/base/UrlLoaderJob.h"
#include "nacl-mounts/console/JSPipeMount.h"
#include "nacl.h"

#define DebugPrintf printf

const uint32_t kSampleFrameCount = 1024u;

int original_main(int argc, char **argv);
void RepaintCallback(void* data, int32_t result);
extern "C" int simple_tar_extract(const char *path);
extern unsigned char S9xMixSamples (unsigned char *buffer, int sample_count);
extern bool sound_initialized;
extern const char* snapshot_filename;

static const string ROM_FILE = "/game.smc";
static string rom_url;

static void download_rom(MainThreadRunner* runner, const string& path,
    const string& local_file) {
  DebugPrintf("Downloading rom from %s to %s\n", path.c_str(),
              local_file.c_str());
  UrlLoaderJob* job = new UrlLoaderJob;
  job->set_url(path.c_str());
  std::vector<char> data;
  job->set_dst(&data);
  runner->RunJob(job);
  int fh = open(local_file.c_str(), O_CREAT | O_WRONLY);
  DebugPrintf("resource fd = %d\n", fh);
  DebugPrintf("wrote %d bytes\n", write(fh, &data[0], data.size()));
  close(fh);
}

static void *snes_init(void *arg) {
  if (rom_url.empty()) {
    DebugPrintf("ROM URL shouldn't be empty!\n");
  }

  mkdir("/savestate", 0777);
  mkdir("/home", 0777);

  MainThreadRunner* runner = reinterpret_cast<MainThreadRunner*>(arg);
  download_rom(runner, rom_url, ROM_FILE);

  DebugPrintf("original_main\n");
  const char *argv[] = { "snes9x", ROM_FILE.c_str() };
  original_main(2, const_cast<char**>(argv));

  return 0;
}

class GlobeInstance : public pp::Instance {
 public:
  explicit GlobeInstance(PP_Instance instance) :
    pp::Instance(instance),
    ready_(false),
    window_width_(0),
    window_height_(0),
    which_image_(0),
    sample_frame_count_(kSampleFrameCount) {
      DebugPrintf("GlobeInstance::GlobeInstance()\n");
  }

  virtual ~GlobeInstance() {
    if (runner_) delete runner_;
  }

  virtual bool Init(uint32_t argc, const char* argn[], const char* argv[]) {
    DebugPrintf("GlobeInstance::Init()\n");

    for (int i = 0; i < argc; ++i) {
      if (strcmp(argn[i], "filename") == 0) {
        rom_url = argv[i];
      }
    }

    InitPixelBuffer();
    initSound();
    S9xNaclInit(static_cast<uint32_t*>(pixel_buffer_->data()),
                pixel_buffer_->stride());

    runner_ = new MainThreadRunner(this);
    pthread_create(&snes_thread_, NULL, snes_init, runner_);
    return true;
  }

  void InitPixelBuffer() {
    size_ = pp::Size(256 * 3, 239 * 3);
    pixel_buffer_ = new pp::ImageData(this,
                                      PP_IMAGEDATAFORMAT_BGRA_PREMUL,
                                      size_, PP_TRUE);
    if (!pixel_buffer_) {
      DebugPrintf("couldn't allocate pixel_buffer_.\n");
      return;
    }
  }

  virtual void DidChangeView(const pp::Rect& position, const pp::Rect& clip) {
    DebugPrintf("GlobeInstance::DidChangeView()\n");
    DebugPrintf("  position.size.width,height = %d, %d\n",
                position.size().width(), position.size().height());
    DebugPrintf("  window.width,height = %d, %d\n", window_width_,
                window_height_);
    size_ = position.size();
    if (false == ready_) {
      graphics_2d_context_ = new pp::Graphics2D(this, size_, false);
      if (!BindGraphics(*graphics_2d_context_)) {
        DebugPrintf("couldn't bind the device context.\n");
        return;
      }
      ready_ = true;
      if (window_width_ != position.size().width() ||
          window_height_ != position.size().height()) {
        // Got a resize, repaint the plugin.
        window_width_ = position.size().width();
        window_height_ = position.size().height();
        Repaint();
      }
    }
    DebugPrintf("GlobeInstance::DidChangeView() Out\n");
  }

  void Repaint() {
    if (ready_ != true) return;

    graphics_2d_context_->PaintImageData(*pixel_buffer_, pp::Point());
    graphics_2d_context_->Flush(pp::CompletionCallback(&RepaintCallback, this));
  }

  string SnapshotName(int index) {
    string filename = snapshot_filename;
    filename[filename.size() - 1] = '0' + index;
    return filename;
  }

  void ReadIntoString(const string& filename, string* result) {
    FILE *fp = fopen(filename.c_str(), "r");
    if (fp == NULL) {
      DebugPrintf("No such file: %s\n", filename.c_str());
      return;
    }
    do {
      char buf[8192];
      size_t size = fread(buf, 1, sizeof(buf), fp);
      if (ferror(fp)) {
        DebugPrintf("Error!");
        fclose(fp);
        return;
      }
      result->append(buf, size);
    } while (!feof(fp));
    fclose(fp);
  }

  // Post the snapshot to JS engine for saving to localStorage.  The message is
  // an ArrayBuffer.  The first byte is the snapshot index ("1"-"9"), followed
  // by file blob.
  void DumpSave(int index) {
    string file = SnapshotName(index);

    // First byte, the index
    string message = "0";
    message[0] += index;

    ReadIntoString(file, &message);

    DebugPrintf("PostMessage: msg len: %d\n", message.size());
    pp::VarArrayBuffer array_buffer(message.size());
    char* data = static_cast<char*>(array_buffer.Map());
    memcpy(data, message.c_str(), message.size());
    PostMessage(array_buffer);
  }

  void LoadSave(const char* data, uint32_t size, int index) {
    FILE *fp = fopen(SnapshotName(index).c_str(), "w");
    if (fp == NULL) {
      return;
    }
    if (fwrite(data, size, 1, fp) < 1) {
       DebugPrintf("error...\n");
    }
    fclose(fp);
  }

  virtual void HandleMessage(const pp::Var& var_message) {
    // ArrayBuffer message always means to load a game save (from localStorage).
    // First byte of the ArrayBuffer is the index of the snapshot. After that
    // are just file blob.
    if (var_message.is_array_buffer()) {
      pp::VarArrayBuffer* array_buffer =
          const_cast<pp::VarArrayBuffer*>(
          reinterpret_cast<const pp::VarArrayBuffer*>(&var_message));

      const char* index = static_cast<char*>(array_buffer->Map());
      const char* data = static_cast<char*>(array_buffer->Map()) + 1;
      uint32_t size = array_buffer->ByteLength() - 1;
      LoadSave(data, size, (*index) - '0');
      return;
    }

    if (!var_message.is_string()) {
      DebugPrintf("HandleMessage: Not string\n");
      return;
    }
    std::string message = var_message.AsString();
    if (message[0] == 'K') {
      int pos = message.find(';');
      if (pos < 0) {
        DebugPrintf("HandleMessage: bad msg: %s\n", message.c_str());
        return;
      }
      string act = message.substr(1, pos - 1);
      string cmd = message.substr(pos + 1);
      event_queue.push(new Event(act, cmd));

      // ACK_SAVE_$N is to tell javascript that SAVE_$N command has been
      // dispatched, so that javascript can send "S $N" command to download to
      // localStorage.  Given threads run in parallel, this approach might not
      // work perfectly (with small chance?).  But I don't know a good way to
      // sync between SNES, main thread and javascript engine.
      if (cmd.substr(0, 5) == "SAVE_") {
        PostMessage(pp::Var("ACK_" + cmd));
      }
    } else if (message[0] == 'V') {
      S9xResizeWindow(atoi(message.substr(1).c_str()));
    } else if (message[0] == 'S') {
      int index = atoi(message.substr(2).c_str());
      DumpSave(index);
    }
  }

  bool initSound() {
    DebugPrintf("initSound\n");
    // Ask the browser/device for an appropriate sample frame count size.
    sample_frame_count_ =
        pp::AudioConfig::RecommendSampleFrameCount(
#ifdef PPB_AUDIO_CONFIG_INTERFACE_1_1
                                                   this,
#endif
                                                   PP_AUDIOSAMPLERATE_44100,
                                                   kSampleFrameCount);
    DebugPrintf("sample_frame_count_ = %d\n", sample_frame_count_ );

    // Create an audio configuration resource.
    pp::AudioConfig audio_config = pp::AudioConfig(this,
                                                   PP_AUDIOSAMPLERATE_44100,
                                                   sample_frame_count_);

    // Create an audio resource.
    audio_ = pp::Audio(this,
                       audio_config,
                       SoundCallback,
                       this);

    // Start playback when the module instance is initialized.
    return audio_.StartPlayback();
  }

  static void SoundCallback(void* samples, uint32_t buffer_size, void* data) {
    if (sound_initialized) {
      S9xMixSamples((unsigned char*)samples, buffer_size / 2);
    }
  }

 private:
  bool ready_;
  int window_width_;
  int window_height_;
  int which_image_;
  uint32_t sample_frame_count_;
  pp::Size size_;
  pp::ImageData* pixel_buffer_;
  pp::Graphics2D* graphics_2d_context_;
  pp::Audio audio_;
  MainThreadRunner* runner_;
  pthread_t snes_thread_;
};

void RepaintCallback(void* data, int32_t result) {
  static_cast<GlobeInstance*>(data)->Repaint();
}

class GlobeModule : public pp::Module {
 public:
  // Override CreateInstance to create your customized Instance object.
  virtual pp::Instance* CreateInstance(PP_Instance instance) {
    return new GlobeInstance(instance);
  }
};

namespace pp {

// factory function for your specialization of the Module object
Module* CreateModule() {
  Module* mm;
  mm = new GlobeModule();
  return mm;
}

}  // namespace pp
