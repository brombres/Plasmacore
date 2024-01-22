#ifndef VULKAN_FUNCTION_H
#define VULKAN_FUNCTION_H

#include <vulkan/vulkan.h>

void AcquireNextImage();

void ResetCommandBuffer();
void BeginCommandBuffer();
void EndCommandBuffer();
void FreeCommandBuffers();

void BeginRenderPass(VkClearColorValue clear_color,VkClearDepthStencilValue clear_depth_stencil);
void EndRenderPass();

void QueueSubmit();
void QueuePresent();

void SetViewport(int width,int height);
void SetScissor(int width,int height);

#endif // VULKAN_FUNCTION_H
