#include "RogueInterface.h"
#include "RogueProgram.h"

//#import <AVFoundation/AVAudioPlayer.h>
//#import <MetalKit/MetalKit.h>

//#ifdef ROGUE_PLATFORM_IOS
//  #import <UIKit/UIKit.h>
//  #import <GLKit/GLKit.h>
//  #import "Project_iOS-Swift.h"
//#else
//  #import "Project_macOS-Swift.h"
//#endif
//
//#include <cstdio>
//#include <cstring>
//using namespace std;

static int    RogueInterface_argc = 0;
static char** RogueInterface_argv = {0};

//-----------------------------------------------------------------------------
// RogueInterface
// Swift <-> Rogue Helpers
//
// SwiftInterface_* calls Swift from Rogue
// RogueInterface_*  calls Rogue from Swift
//-----------------------------------------------------------------------------
void RogueInterface_configure(void)
{
  Rogue_configure( RogueInterface_argc, RogueInterface_argv );
}

void RogueInterface_configure_renderer( CAMetalLayer* ca_metal_layer )
{
  PlasmacoreMoltenVKRenderer__create__RogueVoidPointer( (RogueVoidPointer){(__bridge void *)(ca_metal_layer)} );
}

void RogueInterface_launch(void)
{
  Rogue_launch();
}

void RogueInterface_collect_garbage(void)
{
  Rogue_collect_garbage();
}

/*
bool SwiftInterface_send_message( RogueByte_List* bytes )
{
  NSData* result = [SwiftInterface receiveMessage:bytes->data->as_bytes count:bytes->count];
  if (result)
  {
    RogueInt32 count = (RogueInt32) result.length;
    RogueByte_List__clear( bytes );
    RogueByte_List__reserve__Int32( bytes, count );
    bytes->count = count;
    [result getBytes:bytes->data->as_bytes length:count];
    return true;
  }
  else
  {
    return false;
  }
}

NSData* RogueInterface_send_message( const unsigned char* data, int count )
{
  RogueClassPlasmacore__MessageManager* mm =
    (RogueClassPlasmacore__MessageManager*) ROGUE_SINGLETON(Plasmacore__MessageManager);
  RogueClassPlasmacore__Message* m = RoguePlasmacore__MessageManager__message( mm );
  RogueByte_List* list = m->data;
  RogueByte_List__reserve__Int32( list, count );
  memcpy( list->data->as_bytes, data, count );
  list->count = count;
  RoguePlasmacore__Message__init_from_data( m );

  RogueByte_List* response_data = RoguePlasmacore__MessageManager__receive_message__Plasmacore__Message( mm, m );
  if (response_data)
  {
    return [[NSData alloc] initWithBytes:response_data->data->as_bytes length:response_data->count];
  }
  else
  {
    return nil;
  }
}
*/

void RogueInterface_set_arg_count( int count )
{
  RogueInterface_argc = count;
  RogueInterface_argv = (char**)ROGUE_MALLOC( sizeof(const char*) * (count+1) );
  memset( RogueInterface_argv, 0, sizeof(const char*) * (count+1) );
}

void RogueInterface_set_arg_value( int index, const char* value )
{
  size_t len = strlen( value );
  char* copy = (char*)ROGUE_MALLOC( sizeof(char) * (len+1) );
  strcpy( copy, value );
  RogueInterface_argv[ index ] = copy;
}

/*
bool Bitmap_to_jpeg_bytes( RogueClassBitmap__Bitmap* bitmap, RogueByte_List* bytes )
{
  CGContextRef gc = CGBitmapContextCreate(
    (void*)bitmap->pixels->data->as_int32s, bitmap->width, bitmap->height, 8, bitmap->width*4,
    CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast
  );

  NSData* jpeg_data = [SwiftInterface graphicsContextToJPEGBytes:gc];

  CGContextRelease( gc );

  if (!jpeg_data) return false;

  RogueInt32 count = (RogueInt32)jpeg_data.length;
  bytes->count = count;
  RogueByte_List__reserve__Int32( bytes, count );
  [jpeg_data getBytes:bytes->data->as_bytes length:count];

  return true;
}

bool Bitmap_to_png_bytes( RogueClassBitmap__Bitmap* bitmap, RogueByte_List* bytes )
{
  CGContextRef gc = CGBitmapContextCreate(
    (void*)bitmap->pixels->data->as_int32s, bitmap->width, bitmap->height, 8, bitmap->width*4,
    CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast
  );

  NSData* png_data = [SwiftInterface graphicsContextToPNGBytes:gc];

  CGContextRelease( gc );

  if (!png_data) return false;

  RogueInt32 count = (RogueInt32)png_data.length;
  bytes->count = count;
  RogueByte_List__reserve__Int32( bytes, count );
  [png_data getBytes:bytes->data->as_bytes length:count];

  return true;
}

void Texture_create( RogueInt32 texture_id, RogueInt32 width, RogueInt32 height )
{
  [SwiftInterface createTexture:texture_id :width :height];
}

void Texture_update( RogueInt32 texture_id, RogueInt32 width, RogueInt32 height, RogueByte* bytes )
{
  [SwiftInterface updateTexture:texture_id :width :height :bytes];
}

RogueClassBitmap__Bitmap* Bitmap_decode_image( RogueByte* bytes, RogueInt32 count )
{
  NSData* data = [NSData dataWithBytesNoCopy:bytes length:count freeWhenDone:NO];
#if defined(ROGUE_PLATFORM_IOS)
  CGImageRef bitmap_image = [UIImage imageWithData:data].CGImage;
#else
  CGImageRef bitmap_image = [[[NSImage alloc] initWithData:data] CGImageForProposedRect:NULL context:NULL hints:NULL];
#endif

  if(bitmap_image)
  {
    // Get the width and height of the image
    RogueInt32 width = (RogueInt32)CGImageGetWidth(bitmap_image);
    RogueInt32 height = (RogueInt32)CGImageGetHeight(bitmap_image);
    RogueClassBitmap__Bitmap* bitmap = RogueBitmap__Bitmap__create__Int32_Int32( width, height );

    // Uses the bitmap creation function provided by the Core Graphics framework.
    CGContextRef gc = CGBitmapContextCreate(
                        (void*)bitmap->pixels->data->as_int32s, width, height, 8, width*4,
                        CGColorSpaceCreateDeviceRGB(), kCGImageAlphaPremultipliedLast
                      );
    CGContextDrawImage( gc, CGRectMake(0, 0, (CGFloat)width, (CGFloat)height), bitmap_image );
    CGContextRelease( gc );
    return bitmap;
  }
  else
  {
    return NULL;
  }
}
*/


/*
NSString* Plasmacore_rogue_string_to_ns_string( RogueString* st )
{
  if ( !st ) return nil;
  return [NSString stringWithUTF8String:(const char*)st->utf8];
}

RogueString* Plasmacore_ns_string_to_rogue_string( NSString* st )
{
  if ( !st ) return 0;

  RogueString* result = RogueString_create_from_utf8( [st UTF8String] );
  return RogueString_validate( result );
}

extern "C" RogueString* Plasmacore_get_user_data_folder()
{
  return Plasmacore_ns_string_to_rogue_string(
     [[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject] path]
  );
}

extern "C" RogueString* Plasmacore_get_application_data_folder()
{
  return Plasmacore_ns_string_to_rogue_string(
     [[[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject] path]
  );
}

extern "C" RogueString* Plasmacore_find_asset( RogueString* filepath )
{
  NSString* ns_name = Plasmacore_rogue_string_to_ns_string( filepath );
  NSString* ns_filepath = [[NSBundle mainBundle] pathForResource:ns_name ofType:nil];
  if (ns_filepath == nil) return 0;
  return Plasmacore_ns_string_to_rogue_string( ns_filepath );
}
*/

/*
void* PlasmacoreSound_create( RogueString* filepath, bool is_music )
{
  NSString* ns_filepath = Plasmacore_rogue_string_to_ns_string( filepath );
  AVAudioPlayer* player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:ns_filepath] error:nil];
  [player prepareToPlay];
  return (void*) CFBridgingRetain( player );
}

void PlasmacoreSound_delete( void* sound )
{
  if (sound) CFBridgingRelease( sound );
}

double PlasmacoreSound_duration( void* sound )
{
  if (sound)
  {
    AVAudioPlayer* player = (__bridge AVAudioPlayer*) sound;
    return (double) player.duration;
  }
  else
  {
    return 0.0;
  }
}

bool PlasmacoreSound_is_playing( void* sound )
{
  if (sound)
  {
    AVAudioPlayer* player = (__bridge AVAudioPlayer*) sound;
    return player.playing;
  }
  else
  {
    return false;
  }
}

void PlasmacoreSound_pause( void* sound )
{
  if (sound)
  {
    AVAudioPlayer* player = (__bridge AVAudioPlayer*) sound;
    [player pause];
  }
}

double PlasmacoreSound_position( void* sound )
{
  if (sound)
  {
    AVAudioPlayer* player = (__bridge AVAudioPlayer*) sound;
    return (double) player.currentTime;
  }
  else
  {
    return 0.0;
  }
}

void PlasmacoreSound_play( void* sound, bool repeating )
{
  if (sound)
  {
    AVAudioPlayer* player = (__bridge AVAudioPlayer*) sound;
    player.numberOfLoops = repeating ? -1 : 0;
    [SwiftInterface play_sound:player];
  }
}

void PlasmacoreSound_set_position( void* sound, double to_time )
{
  if (sound)
  {
    AVAudioPlayer* player = (__bridge AVAudioPlayer*) sound;
    player.currentTime = (NSTimeInterval) to_time;
  }
}

void PlasmacoreSound_set_volume( void* sound, double volume )
{
  if (sound)
  {
    AVAudioPlayer* player = (__bridge AVAudioPlayer*) sound;
    player.volume = (float) volume;
  }
}
*/

