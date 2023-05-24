/*
 * Copyright (c) 2015-2019 The Khronos Group Inc.
 * Copyright (c) 2015-2019 Valve Corporation
 * Copyright (c) 2015-2019 LunarG, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Author: Chia-I Wu <olv@lunarg.com>
 * Author: Courtney Goeltzenleuchter <courtney@LunarG.com>
 * Author: Ian Elliott <ian@LunarG.com>
 * Author: Ian Elliott <ianelliott@google.com>
 * Author: Jon Ashburn <jon@lunarg.com>
 * Author: Gwan-gyeong Mun <elongbug@gmail.com>
 * Author: Tony Barbour <tony@LunarG.com>
 * Author: Bill Hollings <bill.hollings@brenwill.com>
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <assert.h>
#include <signal.h>
#if defined(VK_USE_PLATFORM_XLIB_KHR) || defined(VK_USE_PLATFORM_XCB_KHR)
#include <X11/Xutil.h>
#elif defined(VK_USE_PLATFORM_WAYLAND_KHR)
#include <linux/input.h>
#include "xdg-shell-client-header.h"
#include "xdg-decoration-client-header.h"
#endif

#ifdef _WIN32
#ifdef _MSC_VER
#pragma comment(linker, "/subsystem:windows")
#endif  // MSVC
#define APP_NAME_STR_LEN 80
#endif  // _WIN32

#ifdef ANDROID
#include "vulkan_wrapper.h"
#else
#include <vulkan/vulkan.h>
#endif

#include "linmath.h"
#include "object_type_string_helper.h"

#include "gettime.h"
#include "inttypes.h"
#define MILLION 1000000L
#define BILLION 1000000000L

#define DEMO_TEXTURE_COUNT 1
#define APP_SHORT_NAME "vkcube"
#define APP_LONG_NAME "Vulkan Cube"

// Allow a maximum of two outstanding presentation operations.
#define FRAME_LAG 2

#define ARRAY_SIZE(a) (sizeof(a) / sizeof(a[0]))

#if defined(NDEBUG) && defined(__GNUC__)
#define U_ASSERT_ONLY __attribute__((unused))
#else
#define U_ASSERT_ONLY
#endif

#if defined(__GNUC__)
#define UNUSED __attribute__((unused))
#else
#define UNUSED
#endif

#ifdef _WIN32
bool in_callback = false;
#define ERR_EXIT(err_msg, err_class)                                             \
    do {                                                                         \
        if (!demo->suppress_popups) MessageBox(NULL, err_msg, err_class, MB_OK); \
        exit(1);                                                                 \
    } while (0)
void DbgMsg(char *fmt, ...) {
    va_list va;
    va_start(va, fmt);
    vprintf(fmt, va);
    va_end(va);
    fflush(stdout);
}

#elif defined __ANDROID__
#include <android/log.h>
#define ERR_EXIT(err_msg, err_class)                                           \
    do {                                                                       \
        ((void)__android_log_print(ANDROID_LOG_INFO, "Vulkan Cube", err_msg)); \
        exit(1);                                                               \
    } while (0)
#ifdef VARARGS_WORKS_ON_ANDROID
void DbgMsg(const char *fmt, ...) {
    va_list va;
    va_start(va, fmt);
    __android_log_print(ANDROID_LOG_INFO, "Vulkan Cube", fmt, va);
    va_end(va);
}
#else  // VARARGS_WORKS_ON_ANDROID
#define DbgMsg(fmt, ...)                                                                  \
    do {                                                                                  \
        ((void)__android_log_print(ANDROID_LOG_INFO, "Vulkan Cube", fmt, ##__VA_ARGS__)); \
    } while (0)
#endif  // VARARGS_WORKS_ON_ANDROID
#else
#define ERR_EXIT(err_msg, err_class) \
    do {                             \
        printf("%s\n", err_msg);     \
        fflush(stdout);              \
        exit(1);                     \
    } while (0)
void DbgMsg(char *fmt, ...) {
    va_list va;
    va_start(va, fmt);
    vprintf(fmt, va);
    va_end(va);
    fflush(stdout);
}
#endif

#define GET_INSTANCE_PROC_ADDR(inst, entrypoint)                                                              \
    {                                                                                                         \
        demo->fp##entrypoint = (PFN_vk##entrypoint)vkGetInstanceProcAddr(inst, "vk" #entrypoint);             \
        if (demo->fp##entrypoint == NULL) {                                                                   \
            ERR_EXIT("vkGetInstanceProcAddr failed to find vk" #entrypoint, "vkGetInstanceProcAddr Failure"); \
        }                                                                                                     \
    }

static PFN_vkGetDeviceProcAddr g_gdpa = NULL;

#define GET_DEVICE_PROC_ADDR(dev, entrypoint)                                                                    \
    {                                                                                                            \
        if (!g_gdpa) g_gdpa = (PFN_vkGetDeviceProcAddr)vkGetInstanceProcAddr(DEMO_INSTANCE, "vkGetDeviceProcAddr"); \
        demo->fp##entrypoint = (PFN_vk##entrypoint)g_gdpa(dev, "vk" #entrypoint);                                \
        if (demo->fp##entrypoint == NULL) {                                                                      \
            ERR_EXIT("vkGetDeviceProcAddr failed to find vk" #entrypoint, "vkGetDeviceProcAddr Failure");        \
        }                                                                                                        \
    }

#define DEMO_INSTANCE   (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->instance->native_instance.value)
#define DEMO_GPU        (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->gpu->native_gpu.value)
#define DEMO_GPU_NUMBER (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->gpu->index)
#define DEMO_SWAPCHAIN  (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->swapchain->native_swapchain)

#define DEMO_FENCE (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->swapchain->current_frame->fence)
#define DEMO_IMAGE_ACQUIRED_SEMAPHORE  (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->swapchain->current_frame->image_acquired_semaphore)
#define DEMO_DRAW_COMPLETE_SEMAPHORE  (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->swapchain->current_frame->draw_complete_semaphore)
#define DEMO_IMAGE_OWNERSHIP_SEMAPHORE  (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->swapchain->current_frame->image_ownership_semaphore)
#define DEMO_SURFACE (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->surface->native_surface.value)


#define DEMO_GRAPHICS_QUEUE_FAMILY_INDEX (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->graphics_queue_family.index)
#define DEMO_PRESENT_QUEUE_FAMILY_INDEX (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->presentation_queue_family.index)
#define DEMO_SEPARATE_PRESENT_QUEUE (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->uses_separate_presentation_queue)

#define DEMO_DEVICE (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->device->native_device.value)
#define DEMO_GRAPHICS_QUEUE (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->device->graphics_queue)
#define DEMO_PRESENT_QUEUE (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->device->presentation_queue)

#define DEMO_FORMAT (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->surface_format.native_format.value.format)
#define DEMO_COLOR_SPACE (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->surface_format.native_format.value.colorSpace)

#define DEMO_IS_PREPARED  (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->is_prepared)
#define DEMO_IS_MINIMIZED (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->is_minimized)
#define DEMO_WIDTH  (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->swapchain->surface_size.x)
#define DEMO_HEIGHT (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->swapchain->surface_size.y)

#define DEMO_SWAPCHAIN_IMAGE_COUNT (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->swapchain->images->count)
#define DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT(i) ((VulkanVKSwapchainImage*)(ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->swapchain->images->as_objects[i]))
#define DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_I              DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT(i)
#define DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_CURRENT_BUFFER DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT(demo->current_buffer)

#define DEMO_CMD_POOL (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->swapchain->cmd_pool->native_pool.value)
#define DEMO_CMD      (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->swapchain->cmd_buffer->native_buffer.value)

#define DEMO_DEPTH (ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->depth_stencil)

#define DEMO_TEXTURES_AT_I_SAMPLER (((VulkanVKTextureImage*)(ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->textures->as_objects[0]))->native_sampler.value)
#define DEMO_TEXTURES_AT_I_VIEW (((VulkanVKTextureImage*)(ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->textures->as_objects[0]))->native_view.value)

static int validation_error = 0;

struct vktexcube_vs_uniform {
    // Must start with MVP
    float mvp[4][4];
    float position[12 * 3][4];
    float attr[12 * 3][4];
};

//--------------------------------------------------------------------------------------
// Mesh and VertexFormat Data
//--------------------------------------------------------------------------------------
// clang-format off
static const float g_vertex_buffer_data[] = {
    -1.0f,-1.0f,-1.0f,  // -X side
    -1.0f,-1.0f, 1.0f,
    -1.0f, 1.0f, 1.0f,
    -1.0f, 1.0f, 1.0f,
    -1.0f, 1.0f,-1.0f,
    -1.0f,-1.0f,-1.0f,

    -1.0f,-1.0f,-1.0f,  // -Z side
     1.0f, 1.0f,-1.0f,
     1.0f,-1.0f,-1.0f,
    -1.0f,-1.0f,-1.0f,
    -1.0f, 1.0f,-1.0f,
     1.0f, 1.0f,-1.0f,

    -1.0f,-1.0f,-1.0f,  // -Y side
     1.0f,-1.0f,-1.0f,
     1.0f,-1.0f, 1.0f,
    -1.0f,-1.0f,-1.0f,
     1.0f,-1.0f, 1.0f,
    -1.0f,-1.0f, 1.0f,

    -1.0f, 1.0f,-1.0f,  // +Y side
    -1.0f, 1.0f, 1.0f,
     1.0f, 1.0f, 1.0f,
    -1.0f, 1.0f,-1.0f,
     1.0f, 1.0f, 1.0f,
     1.0f, 1.0f,-1.0f,

     1.0f, 1.0f,-1.0f,  // +X side
     1.0f, 1.0f, 1.0f,
     1.0f,-1.0f, 1.0f,
     1.0f,-1.0f, 1.0f,
     1.0f,-1.0f,-1.0f,
     1.0f, 1.0f,-1.0f,

    -1.0f, 1.0f, 1.0f,  // +Z side
    -1.0f,-1.0f, 1.0f,
     1.0f, 1.0f, 1.0f,
    -1.0f,-1.0f, 1.0f,
     1.0f,-1.0f, 1.0f,
     1.0f, 1.0f, 1.0f,
};

static const float g_uv_buffer_data[] = {
    0.0f, 1.0f,  // -X side
    1.0f, 1.0f,
    1.0f, 0.0f,
    1.0f, 0.0f,
    0.0f, 0.0f,
    0.0f, 1.0f,

    1.0f, 1.0f,  // -Z side
    0.0f, 0.0f,
    0.0f, 1.0f,
    1.0f, 1.0f,
    1.0f, 0.0f,
    0.0f, 0.0f,

    1.0f, 0.0f,  // -Y side
    1.0f, 1.0f,
    0.0f, 1.0f,
    1.0f, 0.0f,
    0.0f, 1.0f,
    0.0f, 0.0f,

    1.0f, 0.0f,  // +Y side
    0.0f, 0.0f,
    0.0f, 1.0f,
    1.0f, 0.0f,
    0.0f, 1.0f,
    1.0f, 1.0f,

    1.0f, 0.0f,  // +X side
    0.0f, 0.0f,
    0.0f, 1.0f,
    0.0f, 1.0f,
    1.0f, 1.0f,
    1.0f, 0.0f,

    0.0f, 0.0f,  // +Z side
    0.0f, 1.0f,
    1.0f, 0.0f,
    0.0f, 1.0f,
    1.0f, 1.0f,
    1.0f, 0.0f,
};
// clang-format on

void dumpMatrix(const char *note, mat4x4 MVP) {
    int i;

    printf("%s: \n", note);
    for (i = 0; i < 4; i++) {
        printf("%f, %f, %f, %f\n", MVP[i][0], MVP[i][1], MVP[i][2], MVP[i][3]);
    }
    printf("\n");
    fflush(stdout);
}

void dumpVec4(const char *note, vec4 vector) {
    printf("%s: \n", note);
    printf("%f, %f, %f, %f\n", vector[0], vector[1], vector[2], vector[3]);
    printf("\n");
    fflush(stdout);
}

char const *to_string(VkPhysicalDeviceType const type) {
    switch (type) {
        case VK_PHYSICAL_DEVICE_TYPE_OTHER:
            return "Other";
        case VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU:
            return "IntegratedGpu";
        case VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU:
            return "DiscreteGpu";
        case VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU:
            return "VirtualGpu";
        case VK_PHYSICAL_DEVICE_TYPE_CPU:
            return "Cpu";
        default:
            return "Unknown";
    }
}

struct demo {
    void *caMetalLayer;
    VkSurfaceKHR surface;
    bool prepared;
    bool use_staging_buffer;
    bool is_minimized;
    bool invalid_gpu_selection;

    bool VK_KHR_incremental_present_enabled;

    bool syncd_with_actual_presents;
    uint64_t refresh_duration;
    uint64_t refresh_duration_multiplier;
    uint64_t target_IPD;  // image present duration (inverse of frame rate)
    uint64_t prev_desired_present_time;
    uint32_t next_present_id;
    uint32_t last_early_id;  // 0 if no early images
    uint32_t last_late_id;   // 0 if no late images

    VkPhysicalDeviceMemoryProperties memory_properties;

    int width, height;

    PFN_vkGetPhysicalDeviceSurfaceSupportKHR fpGetPhysicalDeviceSurfaceSupportKHR;
    PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR fpGetPhysicalDeviceSurfaceCapabilitiesKHR;
    PFN_vkGetPhysicalDeviceSurfaceFormatsKHR fpGetPhysicalDeviceSurfaceFormatsKHR;
    PFN_vkGetPhysicalDeviceSurfacePresentModesKHR fpGetPhysicalDeviceSurfacePresentModesKHR;
    PFN_vkCreateSwapchainKHR fpCreateSwapchainKHR;
    PFN_vkDestroySwapchainKHR fpDestroySwapchainKHR;
    PFN_vkGetSwapchainImagesKHR fpGetSwapchainImagesKHR;
    PFN_vkAcquireNextImageKHR fpAcquireNextImageKHR;
    PFN_vkQueuePresentKHR fpQueuePresentKHR;
    PFN_vkGetRefreshCycleDurationGOOGLE fpGetRefreshCycleDurationGOOGLE;
    PFN_vkGetPastPresentationTimingGOOGLE fpGetPastPresentationTimingGOOGLE;
    uint32_t swapchainImageCount;

    VkCommandPool cmd_pool;
    VkCommandPool present_cmd_pool;

    struct {
        VkFormat format;

        VkImage image;
        VkDeviceMemory mem;
        VkImageView view;
    } depth;

    VkCommandBuffer cmd;  // Buffer for initialization commands
    VkPipelineLayout pipeline_layout;
    VkDescriptorSetLayout desc_layout;
    VkPipelineCache pipelineCache;
    VkRenderPass render_pass;
    VkPipeline pipeline;

    mat4x4 projection_matrix;
    mat4x4 view_matrix;
    mat4x4 model_matrix;

    float spin_angle;
    float spin_increment;
    bool pause;

    VkShaderModule vert_shader_module;
    VkShaderModule frag_shader_module;

    VkDescriptorPool desc_pool;

    bool quit;
    int32_t curFrame;
    int32_t frameCount;
    bool validate;
    bool validate_checks_disabled;
    bool use_break;
    bool suppress_popups;
    bool force_errors;

    PFN_vkCreateDebugUtilsMessengerEXT CreateDebugUtilsMessengerEXT;
    PFN_vkDestroyDebugUtilsMessengerEXT DestroyDebugUtilsMessengerEXT;
    PFN_vkSubmitDebugUtilsMessageEXT SubmitDebugUtilsMessageEXT;
    PFN_vkCmdBeginDebugUtilsLabelEXT CmdBeginDebugUtilsLabelEXT;
    PFN_vkCmdEndDebugUtilsLabelEXT CmdEndDebugUtilsLabelEXT;
    PFN_vkCmdInsertDebugUtilsLabelEXT CmdInsertDebugUtilsLabelEXT;
    PFN_vkSetDebugUtilsObjectNameEXT SetDebugUtilsObjectNameEXT;
    VkDebugUtilsMessengerEXT dbg_messenger;

    uint32_t current_buffer;
    uint32_t queue_family_count;
};

VKAPI_ATTR VkBool32 VKAPI_CALL debug_messenger_callback(VkDebugUtilsMessageSeverityFlagBitsEXT messageSeverity,
                                                        VkDebugUtilsMessageTypeFlagsEXT messageType,
                                                        const VkDebugUtilsMessengerCallbackDataEXT *pCallbackData,
                                                        void *pUserData) {
    char prefix[64] = "";
    char *message = (char *)malloc(strlen(pCallbackData->pMessage) + 5000);
    assert(message);
    struct demo *demo = (struct demo *)pUserData;

    if (demo->use_break) {
        raise(SIGTRAP);
    }

    if (messageSeverity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT) {
        strcat(prefix, "VERBOSE : ");
    } else if (messageSeverity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT) {
        strcat(prefix, "INFO : ");
    } else if (messageSeverity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT) {
        strcat(prefix, "WARNING : ");
    } else if (messageSeverity & VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT) {
        strcat(prefix, "ERROR : ");
    }

    if (messageType & VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT) {
        strcat(prefix, "GENERAL");
    } else {
        if (messageType & VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT) {
            strcat(prefix, "VALIDATION");
            validation_error = 1;
        }
        if (messageType & VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT) {
            if (messageType & VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT) {
                strcat(prefix, "|");
            }
            strcat(prefix, "PERFORMANCE");
        }
    }

    sprintf(message, "%s - Message Id Number: %d | Message Id Name: %s\n\t%s\n", prefix, pCallbackData->messageIdNumber,
            pCallbackData->pMessageIdName, pCallbackData->pMessage);
    if (pCallbackData->objectCount > 0) {
        char tmp_message[500];
        sprintf(tmp_message, "\n\tObjects - %d\n", pCallbackData->objectCount);
        strcat(message, tmp_message);
        for (uint32_t object = 0; object < pCallbackData->objectCount; ++object) {
            sprintf(tmp_message, "\t\tObject[%d] - %s", object, string_VkObjectType(pCallbackData->pObjects[object].objectType));
            strcat(message, tmp_message);

            VkObjectType t = pCallbackData->pObjects[object].objectType;
            if (t == VK_OBJECT_TYPE_INSTANCE || t == VK_OBJECT_TYPE_PHYSICAL_DEVICE || t == VK_OBJECT_TYPE_DEVICE ||
                t == VK_OBJECT_TYPE_COMMAND_BUFFER || t == VK_OBJECT_TYPE_QUEUE) {
                sprintf(tmp_message, ", Handle %p", (void *)(uintptr_t)(pCallbackData->pObjects[object].objectHandle));
                strcat(message, tmp_message);
            } else {
                sprintf(tmp_message, ", Handle Ox%" PRIx64, (pCallbackData->pObjects[object].objectHandle));
                strcat(message, tmp_message);
            }

            if (NULL != pCallbackData->pObjects[object].pObjectName && strlen(pCallbackData->pObjects[object].pObjectName) > 0) {
                sprintf(tmp_message, ", Name \"%s\"", pCallbackData->pObjects[object].pObjectName);
                strcat(message, tmp_message);
            }
            sprintf(tmp_message, "\n");
            strcat(message, tmp_message);
        }
    }
    if (pCallbackData->cmdBufLabelCount > 0) {
        char tmp_message[500];
        sprintf(tmp_message, "\n\tCommand Buffer Labels - %d\n", pCallbackData->cmdBufLabelCount);
        strcat(message, tmp_message);
        for (uint32_t cmd_buf_label = 0; cmd_buf_label < pCallbackData->cmdBufLabelCount; ++cmd_buf_label) {
            sprintf(tmp_message, "\t\tLabel[%d] - %s { %f, %f, %f, %f}\n", cmd_buf_label,
                    pCallbackData->pCmdBufLabels[cmd_buf_label].pLabelName, pCallbackData->pCmdBufLabels[cmd_buf_label].color[0],
                    pCallbackData->pCmdBufLabels[cmd_buf_label].color[1], pCallbackData->pCmdBufLabels[cmd_buf_label].color[2],
                    pCallbackData->pCmdBufLabels[cmd_buf_label].color[3]);
            strcat(message, tmp_message);
        }
    }

    printf("%s\n", message);
    fflush(stdout);

    free(message);

    // Don't bail out, but keep going.
    return false;
}

bool ActualTimeLate(uint64_t desired, uint64_t actual, uint64_t rdur) {
    // The desired time was the earliest time that the present should have
    // occured.  In almost every case, the actual time should be later than the
    // desired time.  We should only consider the actual time "late" if it is
    // after "desired + rdur".
    if (actual <= desired) {
        // The actual time was before or equal to the desired time.  This will
        // probably never happen, but in case it does, return false since the
        // present was obviously NOT late.
        return false;
    }
    uint64_t deadline = desired + rdur;
    if (actual > deadline) {
        return true;
    } else {
        return false;
    }
}
bool CanPresentEarlier(uint64_t earliest, uint64_t actual, uint64_t margin, uint64_t rdur) {
    if (earliest < actual) {
        // Consider whether this present could have occured earlier.  Make sure
        // that earliest time was at least 2msec earlier than actual time, and
        // that the margin was at least 2msec:
        uint64_t diff = actual - earliest;
        if ((diff >= (2 * MILLION)) && (margin >= (2 * MILLION))) {
            // This present could have occured earlier because both: 1) the
            // earliest time was at least 2 msec before actual time, and 2) the
            // margin was at least 2msec.
            return true;
        }
    }
    return false;
}

// Forward declarations:
static void demo_resize(struct demo *demo);
static void demo_create_surface(struct demo *demo);

#if defined(__GNUC__) || defined(__clang__)
#define DECORATE_PRINTF(_fmt_argnum, _first_param_num) __attribute__((format(printf, _fmt_argnum, _first_param_num)))
#else
#define DECORATE_PRINTF(_fmt_num, _first_param_num)
#endif

static bool memory_type_from_properties(struct demo *demo, uint32_t typeBits, VkFlags requirements_mask, uint32_t *typeIndex) {
    // Search memtypes to find first index with those properties
    for (uint32_t i = 0; i < VK_MAX_MEMORY_TYPES; i++) {
        if ((typeBits & 1) == 1) {
            // Type is available, does it match user properties?
            if ((demo->memory_properties.memoryTypes[i].propertyFlags & requirements_mask) == requirements_mask) {
                *typeIndex = i;
                return true;
            }
        }
        typeBits >>= 1;
    }
    // No memory types matched, return failure
    return false;
}

static void demo_flush_init_cmd(struct demo *demo) {
    VkResult U_ASSERT_ONLY err;

    // This function could get called twice if the texture uses a staging buffer
    // In that case the second call should be ignored
    if (DEMO_CMD == VK_NULL_HANDLE) return;

    err = vkEndCommandBuffer(DEMO_CMD);
    assert(!err);

    VkFence fence;
    VkFenceCreateInfo fence_ci = {.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, .pNext = NULL, .flags = 0};
    if (demo->force_errors) {
        // Remove sType to intentionally force validation layer errors.
        fence_ci.sType = 0;
    }
    err = vkCreateFence(DEMO_DEVICE, &fence_ci, NULL, &fence);
    assert(!err);

    const VkCommandBuffer cmd_bufs[] = {DEMO_CMD};
    VkSubmitInfo submit_info = {.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
                                .pNext = NULL,
                                .waitSemaphoreCount = 0,
                                .pWaitSemaphores = NULL,
                                .pWaitDstStageMask = NULL,
                                .commandBufferCount = 1,
                                .pCommandBuffers = cmd_bufs,
                                .signalSemaphoreCount = 0,
                                .pSignalSemaphores = NULL};

    err = vkQueueSubmit(DEMO_GRAPHICS_QUEUE, 1, &submit_info, fence);
    assert(!err);

    err = vkWaitForFences(DEMO_DEVICE, 1, &fence, VK_TRUE, UINT64_MAX);
    assert(!err);

    vkFreeCommandBuffers(DEMO_DEVICE, DEMO_CMD_POOL, 1, cmd_bufs);
    vkDestroyFence(DEMO_DEVICE, fence, NULL);
    DEMO_CMD = VK_NULL_HANDLE;
}

static void demo_draw_build_cmd(struct demo *demo, VkCommandBuffer cmd_buf) {
    const VkCommandBufferBeginInfo cmd_buf_info = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .pNext = NULL,
        .flags = VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT,
        .pInheritanceInfo = NULL,
    };
    const VkClearValue clear_values[2] = {
        [0] = {.color.float32 = {0.2f, 0.2f, 0.2f, 0.2f}},
        [1] = {.depthStencil = {1.0f, 0}},
    };
    const VkRenderPassBeginInfo rp_begin = {
        .sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .pNext = NULL,
        .renderPass = demo->render_pass,
        .framebuffer = DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_CURRENT_BUFFER->native_framebuffer.value,
        .renderArea.offset.x = 0,
        .renderArea.offset.y = 0,
        .renderArea.extent.width = DEMO_WIDTH,
        .renderArea.extent.height = DEMO_HEIGHT,
        .clearValueCount = 2,
        .pClearValues = clear_values,
    };
    VkResult U_ASSERT_ONLY err;

    err = vkBeginCommandBuffer(cmd_buf, &cmd_buf_info);

    assert(!err);
    vkCmdBeginRenderPass(cmd_buf, &rp_begin, VK_SUBPASS_CONTENTS_INLINE);

    vkCmdBindPipeline(cmd_buf, VK_PIPELINE_BIND_POINT_GRAPHICS, demo->pipeline);
    vkCmdBindDescriptorSets(cmd_buf, VK_PIPELINE_BIND_POINT_GRAPHICS, demo->pipeline_layout, 0, 1,
                            &DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_CURRENT_BUFFER->descriptor_set.value, 0, NULL);
    VkViewport viewport;
    memset(&viewport, 0, sizeof(viewport));
    float viewport_dimension;
    if (DEMO_WIDTH < DEMO_HEIGHT) {
        viewport_dimension = (float)DEMO_WIDTH;
        viewport.y = (DEMO_HEIGHT - DEMO_WIDTH) / 2.0f;
    } else {
        viewport_dimension = (float)DEMO_HEIGHT;
        viewport.x = (DEMO_WIDTH - DEMO_HEIGHT) / 2.0f;
    }
    viewport.height = viewport_dimension;
    viewport.width = viewport_dimension;
    viewport.minDepth = (float)0.0f;
    viewport.maxDepth = (float)1.0f;
    vkCmdSetViewport(cmd_buf, 0, 1, &viewport);

    VkRect2D scissor;
    memset(&scissor, 0, sizeof(scissor));
    scissor.extent.width = DEMO_WIDTH;
    scissor.extent.height = DEMO_HEIGHT;
    scissor.offset.x = 0;
    scissor.offset.y = 0;
    vkCmdSetScissor(cmd_buf, 0, 1, &scissor);

    vkCmdDraw(cmd_buf, 12 * 3, 1, 0, 0);

    // Note that ending the renderpass changes the image's layout from
    // COLOR_ATTACHMENT_OPTIMAL to PRESENT_SRC_KHR
    vkCmdEndRenderPass(cmd_buf);

    if (DEMO_SEPARATE_PRESENT_QUEUE) {
        // We have to transfer ownership from the graphics queue family to the
        // present queue family to be able to present.  Note that we don't have
        // to transfer from present queue family back to graphics queue family at
        // the start of the next frame because we don't care about the image's
        // contents at that point.
        VkImageMemoryBarrier image_ownership_barrier = {.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                                                        .pNext = NULL,
                                                        .srcAccessMask = 0,
                                                        .dstAccessMask = 0,
                                                        .oldLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
                                                        .newLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
                                                        .srcQueueFamilyIndex = DEMO_GRAPHICS_QUEUE_FAMILY_INDEX,
                                                        .dstQueueFamilyIndex = DEMO_PRESENT_QUEUE_FAMILY_INDEX,
                                                        .image = DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_CURRENT_BUFFER->native_image.value,
                                                        .subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1}};

        vkCmdPipelineBarrier(cmd_buf, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, 0, 0, NULL, 0,
                             NULL, 1, &image_ownership_barrier);
    }
    err = vkEndCommandBuffer(cmd_buf);
    assert(!err);
}

void demo_build_image_ownership_cmd(struct demo *demo, int i) {
    VkResult U_ASSERT_ONLY err;

    const VkCommandBufferBeginInfo cmd_buf_info = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .pNext = NULL,
        .flags = VK_COMMAND_BUFFER_USAGE_SIMULTANEOUS_USE_BIT,
        .pInheritanceInfo = NULL,
    };
    err = vkBeginCommandBuffer(DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_I->cmd_graphics_to_present.value, &cmd_buf_info);
    assert(!err);

    VkImageMemoryBarrier image_ownership_barrier = {.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
                                                    .pNext = NULL,
                                                    .srcAccessMask = 0,
                                                    .dstAccessMask = 0,
                                                    .oldLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
                                                    .newLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
                                                    .srcQueueFamilyIndex = DEMO_GRAPHICS_QUEUE_FAMILY_INDEX,
                                                    .dstQueueFamilyIndex = DEMO_PRESENT_QUEUE_FAMILY_INDEX,
                                                    .image = DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_I->native_image.value,
                                                    .subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1}};

    vkCmdPipelineBarrier(DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_I->cmd_graphics_to_present.value, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
                         VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT, 0, 0, NULL, 0, NULL, 1, &image_ownership_barrier);
    err = vkEndCommandBuffer(DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_I->cmd_graphics_to_present.value);
    assert(!err);
}

void demo_update_data_buffer(struct demo *demo) {
    mat4x4 MVP, Model, VP;
    int matrixSize = sizeof(MVP);

    mat4x4_mul(VP, demo->projection_matrix, demo->view_matrix);

    // Rotate around the Y axis
    mat4x4_dup(Model, demo->model_matrix);
    mat4x4_rotate_Y(demo->model_matrix, Model, (float)degreesToRadians(demo->spin_angle));
    mat4x4_orthonormalize(demo->model_matrix, demo->model_matrix);
    mat4x4_mul(MVP, VP, demo->model_matrix);

    //memcpy(DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_CURRENT_BUFFER->uniform_memory_ptr.value, (const void *)&MVP[0][0], matrixSize);
    PlasmacoreVulkanRenderer* renderer = ROGUE_SINGLETON(PlasmacoreVulkanRenderer);
    VulkanVKSwapchainImage* image = (VulkanVKSwapchainImage*)(renderer->context->swapchain->images->as_objects[demo->current_buffer]);
    memcpy(
      image->uniform_memory_ptr.value, (const void *)&MVP[0][0], matrixSize
    );

}

void DemoUpdateTargetIPD(struct demo *demo) {
    // Look at what happened to previous presents, and make appropriate
    // adjustments in timing:
    VkResult U_ASSERT_ONLY err;
    VkPastPresentationTimingGOOGLE *past = NULL;
    uint32_t count = 0;

    err = demo->fpGetPastPresentationTimingGOOGLE(DEMO_DEVICE, DEMO_SWAPCHAIN, &count, NULL);
    assert(!err);
    if (count) {
        past = (VkPastPresentationTimingGOOGLE *)malloc(sizeof(VkPastPresentationTimingGOOGLE) * count);
        assert(past);
        err = demo->fpGetPastPresentationTimingGOOGLE(DEMO_DEVICE, DEMO_SWAPCHAIN, &count, past);
        assert(!err);

        bool early = false;
        bool late = false;
        bool calibrate_next = false;
        for (uint32_t i = 0; i < count; i++) {
            if (!demo->syncd_with_actual_presents) {
                // This is the first time that we've received an
                // actualPresentTime for this swapchain.  In order to not
                // perceive these early frames as "late", we need to sync-up
                // our future desiredPresentTime's with the
                // actualPresentTime(s) that we're receiving now.
                calibrate_next = true;

                // So that we don't suspect any pending presents as late,
                // record them all as suspected-late presents:
                demo->last_late_id = demo->next_present_id - 1;
                demo->last_early_id = 0;
                demo->syncd_with_actual_presents = true;
                break;
            } else if (CanPresentEarlier(past[i].earliestPresentTime, past[i].actualPresentTime, past[i].presentMargin,
                                         demo->refresh_duration)) {
                // This image could have been presented earlier.  We don't want
                // to decrease the target_IPD until we've seen early presents
                // for at least two seconds.
                if (demo->last_early_id == past[i].presentID) {
                    // We've now seen two seconds worth of early presents.
                    // Flag it as such, and reset the counter:
                    early = true;
                    demo->last_early_id = 0;
                } else if (demo->last_early_id == 0) {
                    // This is the first early present we've seen.
                    // Calculate the presentID for two seconds from now.
                    uint64_t lastEarlyTime = past[i].actualPresentTime + (2 * BILLION);
                    uint32_t howManyPresents = (uint32_t)((lastEarlyTime - past[i].actualPresentTime) / demo->target_IPD);
                    demo->last_early_id = past[i].presentID + howManyPresents;
                } else {
                    // We are in the midst of a set of early images,
                    // and so we won't do anything.
                }
                late = false;
                demo->last_late_id = 0;
            } else if (ActualTimeLate(past[i].desiredPresentTime, past[i].actualPresentTime, demo->refresh_duration)) {
                // This image was presented after its desired time.  Since
                // there's a delay between calling vkQueuePresentKHR and when
                // we get the timing data, several presents may have been late.
                // Thus, we need to threat all of the outstanding presents as
                // being likely late, so that we only increase the target_IPD
                // once for all of those presents.
                if ((demo->last_late_id == 0) || (demo->last_late_id < past[i].presentID)) {
                    late = true;
                    // Record the last suspected-late present:
                    demo->last_late_id = demo->next_present_id - 1;
                } else {
                    // We are in the midst of a set of likely-late images,
                    // and so we won't do anything.
                }
                early = false;
                demo->last_early_id = 0;
            } else {
                // Since this image was not presented early or late, reset
                // any sets of early or late presentIDs:
                early = false;
                late = false;
                calibrate_next = true;
                demo->last_early_id = 0;
                demo->last_late_id = 0;
            }
        }

        if (early) {
            // Since we've seen at least two-seconds worth of presnts that
            // could have occured earlier than desired, let's decrease the
            // target_IPD (i.e. increase the frame rate):
            //
            // TODO(ianelliott): Try to calculate a better target_IPD based
            // on the most recently-seen present (this is overly-simplistic).
            demo->refresh_duration_multiplier--;
            if (demo->refresh_duration_multiplier == 0) {
                // This should never happen, but in case it does, don't
                // try to go faster.
                demo->refresh_duration_multiplier = 1;
            }
            demo->target_IPD = demo->refresh_duration * demo->refresh_duration_multiplier;
        }
        if (late) {
            // Since we found a new instance of a late present, we want to
            // increase the target_IPD (i.e. decrease the frame rate):
            //
            // TODO(ianelliott): Try to calculate a better target_IPD based
            // on the most recently-seen present (this is overly-simplistic).
            demo->refresh_duration_multiplier++;
            demo->target_IPD = demo->refresh_duration * demo->refresh_duration_multiplier;
        }

        if (calibrate_next) {
            int64_t multiple = demo->next_present_id - past[count - 1].presentID;
            demo->prev_desired_present_time = (past[count - 1].actualPresentTime + (multiple * demo->target_IPD));
        }
        free(past);
    }
}

static void demo_draw(struct demo *demo) {
    VkResult U_ASSERT_ONLY err;

    // Ensure no more than FRAME_LAG renderings are outstanding
    vkWaitForFences(DEMO_DEVICE, 1, &DEMO_FENCE, VK_TRUE, UINT64_MAX);
    vkResetFences(DEMO_DEVICE, 1, &DEMO_FENCE);

    do {
        // Get the index of the next available swapchain image:
        err =
            demo->fpAcquireNextImageKHR(DEMO_DEVICE, DEMO_SWAPCHAIN, UINT64_MAX,
                                        DEMO_IMAGE_ACQUIRED_SEMAPHORE, VK_NULL_HANDLE, &demo->current_buffer);

        if (err == VK_ERROR_OUT_OF_DATE_KHR) {
            // DEMO_SWAPCHAIN is out of date (e.g. the window was resized) and
            // must be recreated:
            demo_resize(demo);
        } else if (err == VK_SUBOPTIMAL_KHR) {
            // DEMO_SWAPCHAIN is not as optimal as it could be, but the platform's
            // presentation engine will still present the image correctly.
            break;
        } else if (err == VK_ERROR_SURFACE_LOST_KHR) {
            //vkDestroySurfaceKHR(DEMO_INSTANCE, DEMO_SURFACE, NULL);
            demo_create_surface(demo);
            demo_resize(demo);
        } else {
            assert(!err);
        }
    } while (err != VK_SUCCESS);

    demo_update_data_buffer(demo);

    // Wait for the image acquired semaphore to be signaled to ensure
    // that the image won't be rendered to until the presentation
    // engine has fully released ownership to the application, and it is
    // okay to render to the image.
    VkPipelineStageFlags pipe_stage_flags;
    VkSubmitInfo submit_info;
    submit_info.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    submit_info.pNext = NULL;
    pipe_stage_flags = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
    submit_info.pWaitDstStageMask = &pipe_stage_flags;
    submit_info.waitSemaphoreCount = 1;
    submit_info.pWaitSemaphores = &DEMO_IMAGE_ACQUIRED_SEMAPHORE;
    submit_info.commandBufferCount = 1;
    submit_info.pCommandBuffers = &DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_CURRENT_BUFFER->cmd->native_buffer.value;
    submit_info.signalSemaphoreCount = 1;
    submit_info.pSignalSemaphores = &DEMO_DRAW_COMPLETE_SEMAPHORE;

    //err = vkQueueSubmit(DEMO_GRAPHICS_QUEUE, 1, &submit_info, DEMO_FENCE);
    {
      VkQueue q = DEMO_GRAPHICS_QUEUE;
      VkFence fence = DEMO_FENCE;
      err = vkQueueSubmit(q, 1, &submit_info, fence);
    }
    assert(!err);

    if (DEMO_SEPARATE_PRESENT_QUEUE) {
        // If we are using separate queues, change image ownership to the
        // present queue before presenting, waiting for the draw complete
        // semaphore and signalling the ownership released semaphore when finished
        VkFence nullFence = VK_NULL_HANDLE;
        pipe_stage_flags = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        submit_info.waitSemaphoreCount = 1;
        submit_info.pWaitSemaphores = &DEMO_DRAW_COMPLETE_SEMAPHORE;
        submit_info.commandBufferCount = 1;
        submit_info.pCommandBuffers = &DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_CURRENT_BUFFER->cmd_graphics_to_present.value;
        submit_info.signalSemaphoreCount = 1;
        submit_info.pSignalSemaphores = &DEMO_IMAGE_OWNERSHIP_SEMAPHORE;
        err = vkQueueSubmit(DEMO_PRESENT_QUEUE, 1, &submit_info, nullFence);
        assert(!err);
    }

    // If we are using separate queues we have to wait for image ownership,
    // otherwise wait for draw complete
    VkPresentInfoKHR present = {
        .sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .pNext = NULL,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = (DEMO_SEPARATE_PRESENT_QUEUE) ? &DEMO_IMAGE_OWNERSHIP_SEMAPHORE
                                                          : &DEMO_DRAW_COMPLETE_SEMAPHORE,
        .swapchainCount = 1,
        .pSwapchains = &DEMO_SWAPCHAIN,
        .pImageIndices = &demo->current_buffer,
    };

    VkRectLayerKHR rect;
    VkPresentRegionKHR region;
    VkPresentRegionsKHR regions;
    if (demo->VK_KHR_incremental_present_enabled) {
        // If using VK_KHR_incremental_present, we provide a hint of the region
        // that contains changed content relative to the previously-presented
        // image.  The implementation can use this hint in order to save
        // work/power (by only copying the region in the hint).  The
        // implementation is free to ignore the hint though, and so we must
        // ensure that the entire image has the correctly-drawn content.
        uint32_t eighthOfWidth = DEMO_WIDTH / 8;
        uint32_t eighthOfHeight = DEMO_HEIGHT / 8;

        rect.offset.x = eighthOfWidth;
        rect.offset.y = eighthOfHeight;
        rect.extent.width = eighthOfWidth * 6;
        rect.extent.height = eighthOfHeight * 6;
        rect.layer = 0;

        region.rectangleCount = 1;
        region.pRectangles = &rect;

        regions.sType = VK_STRUCTURE_TYPE_PRESENT_REGIONS_KHR;
        regions.pNext = present.pNext;
        regions.swapchainCount = present.swapchainCount;
        regions.pRegions = &region;
        present.pNext = &regions;
    }

    err = demo->fpQueuePresentKHR(DEMO_PRESENT_QUEUE, &present);
VulkanVKSwapchain__dispatch_advance_frame( ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->swapchain );

    if (err == VK_ERROR_OUT_OF_DATE_KHR) {
        // DEMO_SWAPCHAIN is out of date (e.g. the window was resized) and
        // must be recreated:
        demo_resize(demo);
    } else if (err == VK_SUBOPTIMAL_KHR) {
        // SUBOPTIMAL could be due to a resize
        VkSurfaceCapabilitiesKHR surfCapabilities;
        err = demo->fpGetPhysicalDeviceSurfaceCapabilitiesKHR(DEMO_GPU, DEMO_SURFACE, &surfCapabilities);
        assert(!err);
        if (surfCapabilities.currentExtent.width != (uint32_t)DEMO_WIDTH ||
            surfCapabilities.currentExtent.height != (uint32_t)DEMO_HEIGHT) {
            demo_resize(demo);
        }
    } else if (err == VK_ERROR_SURFACE_LOST_KHR) {
        //vkDestroySurfaceKHR(DEMO_INSTANCE, DEMO_SURFACE, NULL);
        demo_create_surface(demo);
        demo_resize(demo);
    } else {
        assert(!err);
    }
}

void demo_prepare_cube_data_buffers(struct demo *demo) {
    VkBufferCreateInfo buf_info;
    VkMemoryRequirements mem_reqs;
    VkMemoryAllocateInfo mem_alloc;
    mat4x4 MVP, VP;
    VkResult U_ASSERT_ONLY err;
    bool U_ASSERT_ONLY pass;
    struct vktexcube_vs_uniform data;

    mat4x4_mul(VP, demo->projection_matrix, demo->view_matrix);
    mat4x4_mul(MVP, VP, demo->model_matrix);
    memcpy(data.mvp, MVP, sizeof(MVP));
    //    dumpMatrix("MVP", MVP);

    for (unsigned int i = 0; i < 12 * 3; i++) {
        data.position[i][0] = g_vertex_buffer_data[i * 3];
        data.position[i][1] = g_vertex_buffer_data[i * 3 + 1];
        data.position[i][2] = g_vertex_buffer_data[i * 3 + 2];
        data.position[i][3] = 1.0f;
        data.attr[i][0] = g_uv_buffer_data[2 * i];
        data.attr[i][1] = g_uv_buffer_data[2 * i + 1];
        data.attr[i][2] = 0;
        data.attr[i][3] = 0;
    }

    for (unsigned int i = 0; i < DEMO_SWAPCHAIN_IMAGE_COUNT; i++)
    {
      VulkanVKSwapchainImage* image = DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT(i);
      VulkanVKSwapchainImage__configure_uniform_buffer__RogueInt32( image, (RogueInt32)sizeof(data) );
      memcpy( DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_I->uniform_memory_ptr.value, &data, sizeof data );
    }
}

static void demo_prepare_descriptor_layout(struct demo *demo) {
    const VkDescriptorSetLayoutBinding layout_bindings[2] = {
        [0] =
            {
                .binding = 0,
                .descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                .descriptorCount = 1,
                .stageFlags = VK_SHADER_STAGE_VERTEX_BIT,
                .pImmutableSamplers = NULL,
            },
        [1] =
            {
                .binding = 1,
                .descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                .descriptorCount = DEMO_TEXTURE_COUNT,
                .stageFlags = VK_SHADER_STAGE_FRAGMENT_BIT,
                .pImmutableSamplers = NULL,
            },
    };
    const VkDescriptorSetLayoutCreateInfo descriptor_layout = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .pNext = NULL,
        .bindingCount = 2,
        .pBindings = layout_bindings,
    };
    VkResult U_ASSERT_ONLY err;

    err = vkCreateDescriptorSetLayout(DEMO_DEVICE, &descriptor_layout, NULL, &demo->desc_layout);
    assert(!err);

    const VkPipelineLayoutCreateInfo pPipelineLayoutCreateInfo = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .pNext = NULL,
        .setLayoutCount = 1,
        .pSetLayouts = &demo->desc_layout,
    };

    err = vkCreatePipelineLayout(DEMO_DEVICE, &pPipelineLayoutCreateInfo, NULL, &demo->pipeline_layout);
    assert(!err);
}

static void demo_prepare_render_pass(struct demo *demo) {
    // The initial layout for the color and depth attachments will be LAYOUT_UNDEFINED
    // because at the start of the renderpass, we don't care about their contents.
    // At the start of the subpass, the color attachment's layout will be transitioned
    // to LAYOUT_COLOR_ATTACHMENT_OPTIMAL and the depth stencil attachment's layout
    // will be transitioned to LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL.  At the end of
    // the renderpass, the color attachment's layout will be transitioned to
    // LAYOUT_PRESENT_SRC_KHR to be ready to present.  This is all done as part of
    // the renderpass, no barriers are necessary.
    const VkAttachmentDescription attachments[2] = {
        [0] =
            {
                .format = DEMO_FORMAT,
                .flags = 0,
                .samples = VK_SAMPLE_COUNT_1_BIT,
                .loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
                .storeOp = VK_ATTACHMENT_STORE_OP_STORE,
                .stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
                .stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
                .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
                .finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
            },
        [1] =
            {
                .format = DEMO_DEPTH->format.value,
                .flags = 0,
                .samples = VK_SAMPLE_COUNT_1_BIT,
                .loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
                .storeOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
                .stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
                .stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
                .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
                .finalLayout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
            },
    };
    const VkAttachmentReference color_reference = {
        .attachment = 0,
        .layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };
    const VkAttachmentReference depth_reference = {
        .attachment = 1,
        .layout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    };
    const VkSubpassDescription subpass = {
        .pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
        .flags = 0,
        .inputAttachmentCount = 0,
        .pInputAttachments = NULL,
        .colorAttachmentCount = 1,
        .pColorAttachments = &color_reference,
        .pResolveAttachments = NULL,
        .pDepthStencilAttachment = &depth_reference,
        .preserveAttachmentCount = 0,
        .pPreserveAttachments = NULL,
    };

    VkSubpassDependency attachmentDependencies[2] = {
        [0] =
            {
                // Depth buffer is shared between swapchain images
                .srcSubpass = VK_SUBPASS_EXTERNAL,
                .dstSubpass = 0,
                .srcStageMask = VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT | VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
                .dstStageMask = VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT | VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT,
                .srcAccessMask = VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
                .dstAccessMask = VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT | VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT,
                .dependencyFlags = 0,
            },
        [1] =
            {
                // Image Layout Transition
                .srcSubpass = VK_SUBPASS_EXTERNAL,
                .dstSubpass = 0,
                .srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                .dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                .srcAccessMask = 0,
                .dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT | VK_ACCESS_COLOR_ATTACHMENT_READ_BIT,
                .dependencyFlags = 0,
            },
    };

    const VkRenderPassCreateInfo rp_info = {
        .sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .pNext = NULL,
        .flags = 0,
        .attachmentCount = 2,
        .pAttachments = attachments,
        .subpassCount = 1,
        .pSubpasses = &subpass,
        .dependencyCount = 2,
        .pDependencies = attachmentDependencies,
    };
    VkResult U_ASSERT_ONLY err;

    err = vkCreateRenderPass(DEMO_DEVICE, &rp_info, NULL, &demo->render_pass);
    assert(!err);
}

static VkShaderModule demo_prepare_shader_module(const char *name, struct demo *demo, const uint32_t *code, size_t size) {
    VkShaderModule module;
    VkShaderModuleCreateInfo moduleCreateInfo;
    VkResult U_ASSERT_ONLY err;

    moduleCreateInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    moduleCreateInfo.pNext = NULL;
    moduleCreateInfo.flags = 0;
    moduleCreateInfo.codeSize = size;
    moduleCreateInfo.pCode = code;

    err = vkCreateShaderModule(DEMO_DEVICE, &moduleCreateInfo, NULL, &module);
    assert(!err);

    return module;
}

static void demo_prepare_vs(struct demo *demo) {
    const uint32_t vs_code[] = {
#include "cube.vert.inc"
    };
    demo->vert_shader_module = demo_prepare_shader_module("cube.vert", demo, vs_code, sizeof(vs_code));
}

static void demo_prepare_fs(struct demo *demo) {
    const uint32_t fs_code[] = {
#include "cube.frag.inc"
    };
    demo->frag_shader_module = demo_prepare_shader_module("cube.frag", demo, fs_code, sizeof(fs_code));
}

static void demo_prepare_pipeline(struct demo *demo) {
#define NUM_DYNAMIC_STATES 2 /*Viewport + Scissor*/

    VkGraphicsPipelineCreateInfo pipeline;
    VkPipelineCacheCreateInfo pipelineCache;
    VkPipelineVertexInputStateCreateInfo vi;
    VkPipelineInputAssemblyStateCreateInfo ia;
    VkPipelineRasterizationStateCreateInfo rs;
    VkPipelineColorBlendStateCreateInfo cb;
    VkPipelineDepthStencilStateCreateInfo ds;
    VkPipelineViewportStateCreateInfo vp;
    VkPipelineMultisampleStateCreateInfo ms;
    VkDynamicState dynamicStateEnables[NUM_DYNAMIC_STATES];
    VkPipelineDynamicStateCreateInfo dynamicState;
    VkResult U_ASSERT_ONLY err;

    memset(dynamicStateEnables, 0, sizeof dynamicStateEnables);
    memset(&dynamicState, 0, sizeof dynamicState);
    dynamicState.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO;
    dynamicState.pDynamicStates = dynamicStateEnables;

    memset(&pipeline, 0, sizeof(pipeline));
    pipeline.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO;
    pipeline.layout = demo->pipeline_layout;

    memset(&vi, 0, sizeof(vi));
    vi.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO;

    memset(&ia, 0, sizeof(ia));
    ia.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO;
    ia.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;

    memset(&rs, 0, sizeof(rs));
    rs.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO;
    rs.polygonMode = VK_POLYGON_MODE_FILL;
    rs.cullMode = VK_CULL_MODE_BACK_BIT;
    rs.frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE;
    rs.depthClampEnable = VK_FALSE;
    rs.rasterizerDiscardEnable = VK_FALSE;
    rs.depthBiasEnable = VK_FALSE;
    rs.lineWidth = 1.0f;

    memset(&cb, 0, sizeof(cb));
    cb.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO;
    VkPipelineColorBlendAttachmentState att_state[1];
    memset(att_state, 0, sizeof(att_state));
    att_state[0].colorWriteMask = 0xf;
    att_state[0].blendEnable = VK_FALSE;
    cb.attachmentCount = 1;
    cb.pAttachments = att_state;

    memset(&vp, 0, sizeof(vp));
    vp.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO;
    vp.viewportCount = 1;
    dynamicStateEnables[dynamicState.dynamicStateCount++] = VK_DYNAMIC_STATE_VIEWPORT;
    vp.scissorCount = 1;
    dynamicStateEnables[dynamicState.dynamicStateCount++] = VK_DYNAMIC_STATE_SCISSOR;

    memset(&ds, 0, sizeof(ds));
    ds.sType = VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO;
    ds.depthTestEnable = VK_TRUE;
    ds.depthWriteEnable = VK_TRUE;
    ds.depthCompareOp = VK_COMPARE_OP_LESS_OR_EQUAL;
    ds.depthBoundsTestEnable = VK_FALSE;
    ds.back.failOp = VK_STENCIL_OP_KEEP;
    ds.back.passOp = VK_STENCIL_OP_KEEP;
    ds.back.compareOp = VK_COMPARE_OP_ALWAYS;
    ds.stencilTestEnable = VK_FALSE;
    ds.front = ds.back;

    memset(&ms, 0, sizeof(ms));
    ms.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO;
    ms.pSampleMask = NULL;
    ms.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;

    demo_prepare_vs(demo);
    demo_prepare_fs(demo);

    // Two stages: vs and fs
    VkPipelineShaderStageCreateInfo shaderStages[2];
    memset(&shaderStages, 0, 2 * sizeof(VkPipelineShaderStageCreateInfo));

    shaderStages[0].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    shaderStages[0].stage = VK_SHADER_STAGE_VERTEX_BIT;
    shaderStages[0].module = demo->vert_shader_module;
    shaderStages[0].pName = "main";

    shaderStages[1].sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    shaderStages[1].stage = VK_SHADER_STAGE_FRAGMENT_BIT;
    shaderStages[1].module = demo->frag_shader_module;
    shaderStages[1].pName = "main";

    memset(&pipelineCache, 0, sizeof(pipelineCache));
    pipelineCache.sType = VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO;

    err = vkCreatePipelineCache(DEMO_DEVICE, &pipelineCache, NULL, &demo->pipelineCache);
    assert(!err);

    pipeline.pVertexInputState = &vi;
    pipeline.pInputAssemblyState = &ia;
    pipeline.pRasterizationState = &rs;
    pipeline.pColorBlendState = &cb;
    pipeline.pMultisampleState = &ms;
    pipeline.pViewportState = &vp;
    pipeline.pDepthStencilState = &ds;
    pipeline.stageCount = ARRAY_SIZE(shaderStages);
    pipeline.pStages = shaderStages;
    pipeline.renderPass = demo->render_pass;
    pipeline.pDynamicState = &dynamicState;

    pipeline.renderPass = demo->render_pass;

    err = vkCreateGraphicsPipelines(DEMO_DEVICE, demo->pipelineCache, 1, &pipeline, NULL, &demo->pipeline);
    assert(!err);

    vkDestroyShaderModule(DEMO_DEVICE, demo->frag_shader_module, NULL);
    vkDestroyShaderModule(DEMO_DEVICE, demo->vert_shader_module, NULL);
}

static void demo_prepare_descriptor_pool(struct demo *demo) {
    const VkDescriptorPoolSize type_counts[2] = {
        [0] =
            {
                .type = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,
                .descriptorCount = DEMO_SWAPCHAIN_IMAGE_COUNT,
            },
        [1] =
            {
                .type = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER,
                .descriptorCount = DEMO_SWAPCHAIN_IMAGE_COUNT * DEMO_TEXTURE_COUNT,
            },
    };
    const VkDescriptorPoolCreateInfo descriptor_pool = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .pNext = NULL,
        .maxSets = DEMO_SWAPCHAIN_IMAGE_COUNT,
        .poolSizeCount = 2,
        .pPoolSizes = type_counts,
    };
    VkResult U_ASSERT_ONLY err;

    err = vkCreateDescriptorPool(DEMO_DEVICE, &descriptor_pool, NULL, &demo->desc_pool);
    assert(!err);
}

static void demo_prepare_descriptor_set(struct demo *demo) {
    VkDescriptorImageInfo tex_descs[DEMO_TEXTURE_COUNT];
    VkWriteDescriptorSet writes[2];
    VkResult U_ASSERT_ONLY err;

    VkDescriptorSetAllocateInfo alloc_info = {.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
                                              .pNext = NULL,
                                              .descriptorPool = demo->desc_pool,
                                              .descriptorSetCount = 1,
                                              .pSetLayouts = &demo->desc_layout};

    VkDescriptorBufferInfo buffer_info;
    buffer_info.offset = 0;
    buffer_info.range = sizeof(struct vktexcube_vs_uniform);

    memset(&tex_descs, 0, sizeof(tex_descs));
    for (unsigned int i = 0; i < DEMO_TEXTURE_COUNT; i++) {
        tex_descs[i].sampler = DEMO_TEXTURES_AT_I_SAMPLER;
        tex_descs[i].imageView = DEMO_TEXTURES_AT_I_VIEW;
        tex_descs[i].imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
    }

    memset(&writes, 0, sizeof(writes));

    writes[0].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    writes[0].descriptorCount = 1;
    writes[0].descriptorType = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
    writes[0].pBufferInfo = &buffer_info;

    writes[1].sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    writes[1].dstBinding = 1;
    writes[1].descriptorCount = DEMO_TEXTURE_COUNT;
    writes[1].descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
    writes[1].pImageInfo = tex_descs;

    for (unsigned int i = 0; i < DEMO_SWAPCHAIN_IMAGE_COUNT; i++) {
        err = vkAllocateDescriptorSets(DEMO_DEVICE, &alloc_info, &DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_I->descriptor_set.value);
        assert(!err);
        buffer_info.buffer = DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_I->uniform_buffer->native_buffer.value;
        writes[0].dstSet = DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_I->descriptor_set.value;
        writes[1].dstSet = DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_I->descriptor_set.value;
        vkUpdateDescriptorSets(DEMO_DEVICE, 2, writes, 0, NULL);
    }
}

static void demo_prepare_framebuffers(struct demo *demo) {
    VkImageView attachments[2];
    attachments[1] = DEMO_DEPTH->native_view.value;

    const VkFramebufferCreateInfo fb_info = {
        .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
        .pNext = NULL,
        .renderPass = demo->render_pass,
        .attachmentCount = 2,
        .pAttachments = attachments,
        .width = DEMO_WIDTH,
        .height = DEMO_HEIGHT,
        .layers = 1,
    };
    VkResult U_ASSERT_ONLY err;
    uint32_t i;

    for (i = 0; i < DEMO_SWAPCHAIN_IMAGE_COUNT; i++) {
        attachments[0] = DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_I->native_view.value;
        err = vkCreateFramebuffer(DEMO_DEVICE, &fb_info, NULL, &DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_I->native_framebuffer.value);
        assert(!err);
    }
}

static void demo_prepare(struct demo *demo) {
    PlasmacoreVulkanRenderer__dispatch_prepare( ROGUE_SINGLETON(PlasmacoreVulkanRenderer) );

    if (DEMO_IS_MINIMIZED) {
        DEMO_IS_PREPARED = false;
        return;
    }

    VkResult U_ASSERT_ONLY err;

    PlasmacoreVulkanRenderer__dispatch_load_assets( ROGUE_SINGLETON(PlasmacoreVulkanRenderer) );

    demo_prepare_cube_data_buffers(demo);

    //TODO
    demo_prepare_descriptor_layout(demo);
    demo_prepare_render_pass(demo);
    demo_prepare_pipeline(demo);

    //for (uint32_t i = 0; i < DEMO_SWAPCHAIN_IMAGE_COUNT; i++) {
    //    err = vkAllocateCommandBuffers(DEMO_DEVICE, &cmd, &DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_I->cmd->native_buffer.value);
    //    assert(!err);
    //}

    if (DEMO_SEPARATE_PRESENT_QUEUE) {
        const VkCommandPoolCreateInfo present_cmd_pool_info = {
            .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .pNext = NULL,
            .queueFamilyIndex = DEMO_PRESENT_QUEUE_FAMILY_INDEX,
            .flags = 0,
        };
        err = vkCreateCommandPool(DEMO_DEVICE, &present_cmd_pool_info, NULL, &demo->present_cmd_pool);
        assert(!err);
        const VkCommandBufferAllocateInfo present_cmd_info = {
            .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .pNext = NULL,
            .commandPool = demo->present_cmd_pool,
            .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = 1,
        };
        for (uint32_t i = 0; i < DEMO_SWAPCHAIN_IMAGE_COUNT; i++) {
            err = vkAllocateCommandBuffers(DEMO_DEVICE, &present_cmd_info,
                                           &DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_I->cmd_graphics_to_present.value);
            assert(!err);
            demo_build_image_ownership_cmd(demo, i);
        }
    }

    demo_prepare_descriptor_pool(demo);
    demo_prepare_descriptor_set(demo);

    demo_prepare_framebuffers(demo);

    for (uint32_t i = 0; i < DEMO_SWAPCHAIN_IMAGE_COUNT; i++) {
        demo->current_buffer = i;
        demo_draw_build_cmd(demo, DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_I->cmd->native_buffer.value);
    }

    /*
     * Prepare functions above may generate pipeline commands
     * that need to be flushed before beginning the render loop.
     */
    demo_flush_init_cmd(demo);

    demo->current_buffer = 0;
    DEMO_IS_PREPARED = true;
}

static void demo_cleanup(struct demo *demo) {
    uint32_t i;

    DEMO_IS_PREPARED = false;
    vkDeviceWaitIdle(DEMO_DEVICE);

    // Wait for fences from present operations
    for (i = 0; i < FRAME_LAG; i++) {
        vkWaitForFences(DEMO_DEVICE, 1, &DEMO_FENCE, VK_TRUE, UINT64_MAX);
        vkDestroyFence(DEMO_DEVICE, DEMO_FENCE, NULL);
        vkDestroySemaphore(DEMO_DEVICE, DEMO_IMAGE_ACQUIRED_SEMAPHORE, NULL);
        vkDestroySemaphore(DEMO_DEVICE, DEMO_DRAW_COMPLETE_SEMAPHORE, NULL);
        if (DEMO_SEPARATE_PRESENT_QUEUE) {
            vkDestroySemaphore(DEMO_DEVICE, DEMO_IMAGE_OWNERSHIP_SEMAPHORE, NULL);
        }
    }

    // If the window is currently minimized, demo_resize has already done some cleanup for us.
    if (!DEMO_IS_MINIMIZED) {
        PlasmacoreVulkanRenderer__dispatch_reset( ROGUE_SINGLETON(PlasmacoreVulkanRenderer) );

        //for (i = 0; i < DEMO_SWAPCHAIN_IMAGE_COUNT; i++) {
        //    vkDestroyFramebuffer(DEMO_DEVICE, DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_I->native_framebuffer.value, NULL);
        //}
        vkDestroyDescriptorPool(DEMO_DEVICE, demo->desc_pool, NULL);

        vkDestroyPipeline(DEMO_DEVICE, demo->pipeline, NULL);
        vkDestroyPipelineCache(DEMO_DEVICE, demo->pipelineCache, NULL);
        vkDestroyRenderPass(DEMO_DEVICE, demo->render_pass, NULL);
        vkDestroyPipelineLayout(DEMO_DEVICE, demo->pipeline_layout, NULL);
        vkDestroyDescriptorSetLayout(DEMO_DEVICE, demo->desc_layout, NULL);

        demo->fpDestroySwapchainKHR(DEMO_DEVICE, DEMO_SWAPCHAIN, NULL);

        vkDestroyImageView(DEMO_DEVICE, DEMO_DEPTH->native_view.value, NULL);
        vkDestroyImage(DEMO_DEVICE, DEMO_DEPTH->native_image.value, NULL);
        vkFreeMemory(DEMO_DEVICE, DEMO_DEPTH->native_memory.value, NULL);

        if (DEMO_SEPARATE_PRESENT_QUEUE) {
            vkDestroyCommandPool(DEMO_DEVICE, demo->present_cmd_pool, NULL);
        }
    }
    vkDeviceWaitIdle(DEMO_DEVICE);
    vkDestroyDevice(DEMO_DEVICE, NULL);
    if (demo->validate) {
        demo->DestroyDebugUtilsMessengerEXT(DEMO_INSTANCE, demo->dbg_messenger, NULL);
    }
    vkDestroySurfaceKHR(DEMO_INSTANCE, DEMO_SURFACE, NULL);

    vkDestroyInstance(DEMO_INSTANCE, NULL);
}

static void demo_resize(struct demo *demo) {
    uint32_t i;
    // Don't react to resize until after first initialization.
    if (!DEMO_IS_PREPARED) {
        if (DEMO_IS_MINIMIZED) {
            demo_prepare(demo);
        }
        return;
    }
    // In order to properly resize the window, we must re-create the swapchain
    // AND redo the command buffers, etc.
    //
    // First, perform part of the demo_cleanup() function:

    DEMO_IS_PREPARED = false;
    vkDeviceWaitIdle(DEMO_DEVICE);

    PlasmacoreVulkanRenderer__dispatch_reset( ROGUE_SINGLETON(PlasmacoreVulkanRenderer) );

    //for (i = 0; i < DEMO_SWAPCHAIN_IMAGE_COUNT; i++) {
    //    vkDestroyFramebuffer(DEMO_DEVICE, DEMO_SWAPCHAIN_IMAGE_RESOURCES_AT_I->native_framebuffer.value, NULL);
    //}
    vkDestroyDescriptorPool(DEMO_DEVICE, demo->desc_pool, NULL);

    vkDestroyPipeline(DEMO_DEVICE, demo->pipeline, NULL);
    vkDestroyPipelineCache(DEMO_DEVICE, demo->pipelineCache, NULL);
    vkDestroyRenderPass(DEMO_DEVICE, demo->render_pass, NULL);
    vkDestroyPipelineLayout(DEMO_DEVICE, demo->pipeline_layout, NULL);
    vkDestroyDescriptorSetLayout(DEMO_DEVICE, demo->desc_layout, NULL);

    vkDestroyImageView(DEMO_DEVICE, DEMO_DEPTH->native_view.value, NULL);
    vkDestroyImage(DEMO_DEVICE, DEMO_DEPTH->native_image.value, NULL);
    vkFreeMemory(DEMO_DEVICE, DEMO_DEPTH->native_memory.value, NULL);

    if (DEMO_SEPARATE_PRESENT_QUEUE) {
        vkDestroyCommandPool(DEMO_DEVICE, demo->present_cmd_pool, NULL);
    }

    // Second, re-perform the demo_prepare() function, which will re-create the
    // swapchain:
    demo_prepare(demo);
}

// On MS-Windows, make this a global, so it's available to WndProc()
struct demo demo;

static void demo_run(struct demo *demo) {
    demo_draw(demo);
    demo->curFrame++;
    VulkanVKSwapchain__dispatch_advance_frame( ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->swapchain );
    if (demo->frameCount != INT32_MAX && demo->curFrame == demo->frameCount) {
        demo->quit = TRUE;
    }
}

/*
 * Return 1 (true) if all layer names specified in check_names
 * can be found in given layer properties.
 */
static VkBool32 demo_check_layers(uint32_t check_count, char **check_names, uint32_t layer_count, VkLayerProperties *layers) {
    for (uint32_t i = 0; i < check_count; i++) {
        VkBool32 found = 0;
        for (uint32_t j = 0; j < layer_count; j++) {
            if (!strcmp(check_names[i], layers[j].layerName)) {
                found = 1;
                break;
            }
        }
        if (!found) {
            fprintf(stderr, "Cannot find layer: %s\n", check_names[i]);
            return 0;
        }
    }
    return 1;
}

static void demo_init_vk(struct demo *demo) {
    VkResult err;
    DEMO_IS_MINIMIZED = false;

    // Query fine-grained feature support for this device.
    //  If app has specific feature requirements it should check supported
    //  features based on this query
    //VkPhysicalDeviceFeatures physDevFeatures;
    //vkGetPhysicalDeviceFeatures(DEMO_GPU, &physDevFeatures);

    GET_INSTANCE_PROC_ADDR(DEMO_INSTANCE, GetPhysicalDeviceSurfaceSupportKHR);
    GET_INSTANCE_PROC_ADDR(DEMO_INSTANCE, GetPhysicalDeviceSurfaceCapabilitiesKHR);
    GET_INSTANCE_PROC_ADDR(DEMO_INSTANCE, GetPhysicalDeviceSurfaceFormatsKHR);
    GET_INSTANCE_PROC_ADDR(DEMO_INSTANCE, GetPhysicalDeviceSurfacePresentModesKHR);
    GET_INSTANCE_PROC_ADDR(DEMO_INSTANCE, GetSwapchainImagesKHR);
}

static void demo_create_device(struct demo *demo) {
    PlasmacoreVulkanRenderer* renderer = ROGUE_SINGLETON(PlasmacoreVulkanRenderer);
    PlasmacoreVulkanRenderer__dispatch_create_device( renderer );
}

static void demo_create_surface(struct demo *demo) {

    PlasmacoreVulkanRenderer* renderer = ROGUE_SINGLETON(PlasmacoreVulkanRenderer);
    PlasmacoreVulkanRenderer__dispatch_create_surface( renderer );
}

static void demo_init_vk_swapchain(struct demo *demo) {
    demo_create_surface(demo);

//TODO
    demo_create_device(demo);

    GET_DEVICE_PROC_ADDR(DEMO_DEVICE, CreateSwapchainKHR);
    GET_DEVICE_PROC_ADDR(DEMO_DEVICE, DestroySwapchainKHR);
    GET_DEVICE_PROC_ADDR(DEMO_DEVICE, GetSwapchainImagesKHR);
    GET_DEVICE_PROC_ADDR(DEMO_DEVICE, AcquireNextImageKHR);
    GET_DEVICE_PROC_ADDR(DEMO_DEVICE, QueuePresentKHR);

    demo->quit = false;
    demo->curFrame = 0;

    VulkanVKSwapchain__dispatch_create_semaphores( ROGUE_SINGLETON(PlasmacoreVulkanRenderer)->context->swapchain );

    // Get Memory information and properties
    vkGetPhysicalDeviceMemoryProperties(DEMO_GPU, &demo->memory_properties);
}


static void demo_init_connection(struct demo *demo) {
}

static void demo_init(struct demo *demo, int argc, char **argv) {
    vec3 eye = {0.0f, 3.0f, 5.0f};
    vec3 origin = {0, 0, 0};
    vec3 up = {0.0f, 1.0f, 0.0};

    memset(demo, 0, sizeof(*demo));
    demo->frameCount = INT32_MAX;
    /* Autodetect suitable / best GPU by default */
    DEMO_GPU_NUMBER = -1;
    DEMO_WIDTH = 500;
    DEMO_HEIGHT = 500;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--use_staging") == 0) {
            demo->use_staging_buffer = true;
            continue;
        }
        if ((strcmp(argv[i], "--present_mode") == 0) && (i < argc - 1)) {
            //DEMO_PRESENT_MODE = atoi(argv[i + 1]);
            i++;
            continue;
        }
        if (strcmp(argv[i], "--break") == 0) {
            demo->use_break = true;
            continue;
        }
        if (strcmp(argv[i], "--validate") == 0) {
            demo->validate = true;
            continue;
        }
        if (strcmp(argv[i], "--validate-checks-disabled") == 0) {
            demo->validate = true;
            demo->validate_checks_disabled = true;
            continue;
        }
        if (strcmp(argv[i], "--xlib") == 0) {
            fprintf(stderr, "--xlib is deprecated and no longer does anything");
            continue;
        }
        if (strcmp(argv[i], "--c") == 0 && demo->frameCount == INT32_MAX && i < argc - 1 &&
            sscanf(argv[i + 1], "%d", &demo->frameCount) == 1 && demo->frameCount >= 0) {
            i++;
            continue;
        }
        if (strcmp(argv[i], "--width") == 0) {
            if (i < argc - 1 && sscanf(argv[i + 1], "%d", &DEMO_WIDTH) == 1) {
                if (DEMO_WIDTH > 0) {
                    i++;
                    continue;
                } else {
                    ERR_EXIT("The --width parameter must be greater than 0", "User Error");
                }
            }
            ERR_EXIT("The --width parameter must be followed by a number", "User Error");
        }
        if (strcmp(argv[i], "--height") == 0) {
            if (i < argc - 1 && sscanf(argv[i + 1], "%d", &DEMO_HEIGHT) == 1) {
                if (DEMO_HEIGHT > 0) {
                    i++;
                    continue;
                } else {
                    ERR_EXIT("The --height parameter must be greater than 0", "User Error");
                }
            }
            ERR_EXIT("The --height parameter must be followed by a number", "User Error");
        }
        if (strcmp(argv[i], "--suppress_popups") == 0) {
            demo->suppress_popups = true;
            continue;
        }
        if (strcmp(argv[i], "--display_timing") == 0) {
            //demo->VK_GOOGLE_display_timing_enabled = true;
            continue;
        }
        if (strcmp(argv[i], "--incremental_present") == 0) {
            demo->VK_KHR_incremental_present_enabled = true;
            continue;
        }
        if ((strcmp(argv[i], "--gpu_number") == 0) && (i < argc - 1)) {
            DEMO_GPU_NUMBER = atoi(argv[i + 1]);
            if (DEMO_GPU_NUMBER < 0) demo->invalid_gpu_selection = true;
            i++;
            continue;
        }
        if (strcmp(argv[i], "--force_errors") == 0) {
            demo->force_errors = true;
            continue;
        }

        char *message =
            "Usage:\n  %s\t[--use_staging] [--validate] [--validate-checks-disabled]\n"
            "\t[--break] [--c <framecount>] [--suppress_popups]\n"
            "\t[--incremental_present] [--display_timing]\n"
            "\t[--gpu_number <index of physical device>]\n"
            "\t[--present_mode <present mode enum>]\n"
            "\t[--width <width>] [--height <height>]\n"
            "\t[--force_errors]\n"
            "\t<present_mode_enum>\n"
            "\t\tVK_PRESENT_MODE_IMMEDIATE_KHR = %d\n"
            "\t\tVK_PRESENT_MODE_MAILBOX_KHR = %d\n"
            "\t\tVK_PRESENT_MODE_FIFO_KHR = %d\n"
            "\t\tVK_PRESENT_MODE_FIFO_RELAXED_KHR = %d\n";
        int length = snprintf(NULL, 0, message, APP_SHORT_NAME, VK_PRESENT_MODE_IMMEDIATE_KHR, VK_PRESENT_MODE_MAILBOX_KHR,
                              VK_PRESENT_MODE_FIFO_KHR, VK_PRESENT_MODE_FIFO_RELAXED_KHR);
        char *usage = (char *)malloc(length + 1);
        if (!usage) {
            exit(1);
        }
        snprintf(usage, length + 1, message, APP_SHORT_NAME, VK_PRESENT_MODE_IMMEDIATE_KHR, VK_PRESENT_MODE_MAILBOX_KHR,
                 VK_PRESENT_MODE_FIFO_KHR, VK_PRESENT_MODE_FIFO_RELAXED_KHR);
        fprintf(stderr, "%s", usage);
        fflush(stderr);

        free(usage);
        exit(1);
    }

    demo_init_connection(demo);

    demo_init_vk(demo);

    demo->spin_angle = 4.0f;
    demo->spin_increment = 0.2f;
    demo->pause = false;

    mat4x4_perspective(demo->projection_matrix, (float)degreesToRadians(45.0f), 1.0f, 0.1f, 100.0f);
    mat4x4_look_at(demo->view_matrix, eye, origin, up);
    mat4x4_identity(demo->model_matrix);

    demo->projection_matrix[1][1] *= -1;  // Flip projection matrix from GL to Vulkan orientation.
}

static void demo_main(struct demo *demo, void *caMetalLayer, int argc, const char *argv[]) {
    demo_init(demo, argc, (char **)argv);
    demo->caMetalLayer = caMetalLayer;
    demo_init_vk_swapchain(demo);
    demo_prepare(demo);
    demo->spin_angle = 0.4f;
}

