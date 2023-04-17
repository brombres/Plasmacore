#include "CubeWrapper.h"

#define VK_USE_PLATFORM_METAL_EXT 1
#include "../../MoltenVK/External/Vulkan-Tools/cube/cube.c"

static struct demo cube_demo;

void call_demo_main( void *caMetalLayer, int argc, const char *argv[] )
{
  demo_main( &cube_demo, caMetalLayer, argc, argv );
}

void call_demo_draw()
{
  demo_draw( &cube_demo );
}
