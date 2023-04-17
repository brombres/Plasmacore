#include "CubeInterface.h"
#include "CubeWrapper.h"

void CubeInterface_configure( CAMetalLayer* layer )
{
  const char* argv[] = { "cube" };
  call_demo_main( (__bridge void *)(layer), 1, argv );
}

void CubeInterface_render(void)
{
  call_demo_draw();
}

