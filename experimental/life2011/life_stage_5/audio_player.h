// Copyright 2011 The Native Client Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
#ifndef AUDIO_PLAYER_H_
#define AUDIO_PLAYER_H_

#include "web_resource_loader.h"

namespace pp {
class Audio;
class Instance;
}

namespace life {

class AudioSource;

// Play audio from various audio sources. Usage:
//
//   AudioPlayer player(instance);
//   AudioSource* source = <create an sudio source>
//   player.AssignAudioSource(source);
//   player.Play();
class AudioPlayer {
 public:
  AudioPlayer(pp::Instance* instance);
  ~AudioPlayer();

  // Assign an audio source to this player. The player owns the audio source and
  // is responsible for deleting it when done. Returns true if successful, and
  // false otherwise (e.g. the source is not playable through this player).
  void AssignAudioSource(AudioSource* source);

  // Play audio from the sound source. This is an asynchronous call that returns
  // immediately. Fails silently if the sound source is not ready.
  void Play();
  // Stop playing.
  void Stop();

 private:
  // Disallow copy and assigment.
  AudioPlayer(const AudioPlayer&);
  AudioPlayer&  operator=(const AudioPlayer&);

  // Pepper audio callback function.
  static void AudioCallback(void* sample_buffer, size_t buffer_size_in_bytes,
                            void* user_data);

  // StopPlaying is callable from any thread or the audio callback to stop
  // playing the sound. It uses the callback that follows to schedule the
  // action on the main thread.
  void StopPlaying();
  static void StopPlayingCallback(void* user_data, int32_t err);

  // Clear (delete) the audio objects. 
  void ClearAudioSource();
  void ClearPepperAudio();
  // Create the pepper audio for the given sopurce. Return true on success.
  bool CreatePepperAudio();

  AudioSource* audio_source_;
  size_t playback_offset_;
  pp::Audio* pp_audio_;
  pp::Instance* instance_;
};

}  // namespace life
#endif  // AUDIO_PLAYER_H_
