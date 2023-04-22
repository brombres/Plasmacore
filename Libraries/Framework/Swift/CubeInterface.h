#ifndef CUBE_INTERFACE_H
#define CUBE_INTERFACE_H

#ifdef PLASMACORE_PLATFORM_MAC
  #import <Cocoa/Cocoa.h>
#else
  #import <Foundation/Foundation.h>
#endif

#import <QuartzCore/QuartzCore.h>

#ifdef __cplusplus
extern "C" {
#endif

void CubeInterface_configure(void);
void CubeInterface_render(void);

//static void demo_main(struct demo *demo, void *caMetalLayer, int argc, const char *argv[]) {

#ifdef __cplusplus
} // extern "C"
#endif

#endif // CUBE_INTERFACE_H
