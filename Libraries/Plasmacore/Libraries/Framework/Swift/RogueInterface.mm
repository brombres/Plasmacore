#include "RogueInterface.h"
//#include "RogueProgram.h"

//#import <AVFoundation/AVAudioPlayer.h>


#ifdef PLASMACORE_PLATFORM_IOS
//  #import <UIKit/UIKit.h>
//  #import <GLKit/GLKit.h>
  //#import "Project-iOS-Swift.h"
#else
  #import "Plasmacore-macOS-Swift.h"
#endif

#include <cstdio>
#include <cstring>
using namespace std;

static int          RogueInterface_argc = 0;
static const char** RogueInterface_argv = {0};

void RogueInterface_configure()
{
  printf("RogueInterface_configure()\n");
}

