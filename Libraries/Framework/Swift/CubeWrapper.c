#include "CubeWrapper.h"

#include "RogueProgram.h"

#define VK_USE_PLATFORM_METAL_EXT 1
#include "../../../Source/cube.c"

static struct demo cube_demo = {0};

void call_demo_main( int argc, const char *argv[] )
{
  //demo_main( &cube_demo, caMetalLayer, argc, argv );
  demo_init(&cube_demo, argc, (char **)argv);
  cube_demo.caMetalLayer = ROGUE_SINGLETON(PlasmacoreMoltenVKRenderer)->ca_metal_layer;
  demo_init_vk_swapchain( &cube_demo );
  demo_prepare( &cube_demo );
  cube_demo.spin_angle = 0.4f;
}

void call_demo_draw( void )
{
  demo_draw( &cube_demo );
}
