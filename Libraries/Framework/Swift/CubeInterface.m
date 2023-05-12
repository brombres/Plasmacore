#include "CubeInterface.h"
#include "CubeWrapper.h"

void CubeInterface_configure(void)
{
  const char* argv[] = { "cube" };
  call_demo_main( 1, argv );
}

void CubeInterface_prepare(void)
{
  call_demo_prepare();
}

void CubeInterface_render(void)
{
  call_demo_draw();
}

