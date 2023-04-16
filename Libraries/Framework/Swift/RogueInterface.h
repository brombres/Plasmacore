#ifndef ROGUE_INTERFACE_H
#define ROGUE_INTERFACE_H

#include "TargetConditionals.h"

#if defined(__APPLE__)
  #if defined(TARGET_IPHONE_SIMULATOR)
    #if TARGET_IPHONE_SIMULATOR
      #define PLASMACORE_PLATFORM_IOS           1
      #define PLASMACORE_PLATFORM_IOS_SIMULATOR 1
    #endif
  #endif

  #if !defined(PLASMACORE_PLATFORM_IOS)
    #if defined(TARGET_OS_IPHONE)
      #if TARGET_OS_IPHONE
        #define PLASMACORE_PLATFORM_IOS        1
        #define PLASMACORE_PLATFORM_IOS_DEVICE 1
      #endif
    #endif
  #endif

  #if !defined(PLASMACORE_PLATFORM_IOS)
    #define PLASMACORE_PLATFORM_MACOS           1
    #define PLASMACORE_PLATFORM_UNIX_COMPATIBLE 1
  #endif
#endif

#ifdef PLASMACORE_PLATFORM_MAC
  #import <Cocoa/Cocoa.h>
#else
  #import <Foundation/Foundation.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

void    RogueInterface_configure(void);
void    RogueInterface_launch(void);
void    RogueInterface_collect_garbage(void);
NSData* RogueInterface_send_message( const unsigned char* data, int count );
void    RogueInterface_set_arg_count( int count );
void    RogueInterface_set_arg_value( int index, const char* value );

#ifdef __cplusplus
} // extern "C"
#endif

#endif // ROGUE_INTERFACE_H
