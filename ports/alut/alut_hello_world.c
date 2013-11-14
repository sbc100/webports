#include <stdlib.h>
#include <stdio.h>
#include <AL/alut.h>

#include <ppapi_main/ppapi_main.h>
#include <ppapi/c/ppb.h>

/*
  This is the 'Hello World' program from the ALUT
  reference manual.

  Link using '-lalut -lopenal -lpthread'.
*/

PPAPI_MAIN_WITH_DEFAULT_ARGS

void alSetPpapiInfo(PP_Instance instance, PPB_GetInterface get_interface);

int
ppapi_main(int argc, const char *argv[])
{
  ALuint helloBuffer, helloSource;

  /*
   * This extra line is required by the underlying openAl
   * NaCl port.
   */
  alSetPpapiInfo (PPAPI_GetInstanceId(), PPAPI_GetInterface);

  alutInit (&argc, (char**)argv);
  helloBuffer = alutCreateBufferHelloWorld ();
  alGenSources (1, &helloSource);
  alSourcei (helloSource, AL_BUFFER, helloBuffer);
  alSourcePlay (helloSource);
  alutSleep (1);
  alutExit ();
  return EXIT_SUCCESS;
}
