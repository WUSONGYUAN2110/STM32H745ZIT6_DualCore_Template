cmake_minimum_required(VERSION 3.22)

#
# This file is generated only once,
# and is not re-generated if converter is called multiple times.
#
# User is free to modify the file as much as necessary
#

# Setup compiler settings
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)

# Define the build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug")
endif()

message("Build type: " ${CMAKE_BUILD_TYPE})

# Enable compile command to ease indexing with e.g. clangd
set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)

# Compiler options
set(STM32_MCU_FLAGS  "-mcpu=cortex-m7 -mfpu=fpv5-d16 -mfloat-abi=hard")

#Linker options
set(STM32_LINKER_SCRIPT Linker/stm32h745xx_flash_CM7.ld)
set(STM32_LINKER_OPTION  )

# Set the project name
set(CMAKE_PROJECT_NAME Project_CM7)
project(${CMAKE_PROJECT_NAME})

# Create an executable object type
add_executable(${CMAKE_PROJECT_NAME})

# Include mx-generated
include("mx-generated.cmake")

# Keep CubeMX-generated HAL config headers untouched while satisfying -Wundef.
target_compile_definitions(stm32cubemx INTERFACE USE_FLASH_ECC=0U)

# Add project symbols (macros)
target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE
    # Enable CM7<->CM4 boot handshake via HSEM_0.
    # Comment out when debugging CM7 alone (no CM4 image flashed).
    DUAL_CORE_BOOT_SYNC_SEQUENCE
    # Note: DISABLEFLOAT16 is intentionally NOT here — it is attached to the
    # `stm32cubemx` INTERFACE library further below (after include of
    # mx-generated.cmake) so every target that links HAL inherits it.
    # Add user defined symbols
)

# Enable CMake support for ASM and C languages
enable_language(C ASM)

# Add include paths
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
    # Add user defined include paths
)

# Add sources to executable
target_sources(${CMAKE_PROJECT_NAME} PRIVATE
    # Add user sources here
)

# Link directories setup
target_link_directories(${CMAKE_PROJECT_NAME} PRIVATE
    # Add user defined library search paths
)

# Add linked libraries
# NOTE: mx-generated.cmake uses the *plain* (non-keyword) signature of
# target_link_libraries, so all calls on this target must also be plain.
# Do NOT add PRIVATE/PUBLIC/INTERFACE here.
target_link_libraries(${CMAKE_PROJECT_NAME}
    # Add user defined libraries
)

# ===========================================================================
# CMSIS-DSP (CM7 only — CM4 does not include this library)
#
# Builds Drivers/CMSIS-DSP into a static library named CMSISDSP. The library
# inherits the parent's -mcpu=cortex-m7 -mfpu=fpv5-d16 -mfloat-abi=hard so
# all source files are compiled for the M7 FPU.
#
# DISABLEFLOAT16=ON   : Cortex-M7 (FPv5-D16) has no FP16 arithmetic hardware,
#                       skip _f16 sources to avoid build errors.
# LOOPUNROLL=ON       : default; trades flash for speed.
# FASTBUILD=ON        : build upstream aggregate translation units for a much
#                       faster Cortex-M library build; function sections still
#                       allow the linker to discard unused kernels.
# Other knobs (NEON/HELIUM/MVE) stay OFF — none apply to Cortex-M7.
# ===========================================================================
set(CMSISCORE      "${CMAKE_CURRENT_SOURCE_DIR}/../Drivers/CMSIS" CACHE PATH "" FORCE)
set(DISABLEFLOAT16 ON  CACHE BOOL "" FORCE)
set(LOOPUNROLL     ON  CACHE BOOL "" FORCE)
set(FASTBUILD      ON  CACHE BOOL "" FORCE)
add_subdirectory(
    "${CMAKE_CURRENT_SOURCE_DIR}/../Drivers/CMSIS-DSP"
    "${CMAKE_CURRENT_BINARY_DIR}/CMSIS-DSP"
)

# Propagate DISABLEFLOAT16 to every consumer of HAL (and thus arm_math.h).
# CMSIS-DSP's own configDsp.cmake only sets this PRIVATE on CMSISDSP, so the
# library is built without _f16 kernels but consumers including <arm_math.h>
# would still see _f16 prototypes — link would then fail. The `stm32cubemx`
# INTERFACE library is the propagation hub: STM32_Drivers, ${CMAKE_PROJECT_NAME}
# and any future sub-library that links HAL automatically inherits this define.
# stm32cubemx is created in mx-generated.cmake (included above) so it exists here.
target_compile_definitions(stm32cubemx INTERFACE DISABLEFLOAT16)

# Force CMSIS-DSP to -O3 regardless of CMAKE_BUILD_TYPE. Debug builds otherwise
# inherit -Og from CMAKE_C_FLAGS_DEBUG, which is still unsuitable for reliable
# DSP performance measurements.
# target_compile_options comes after CMAKE_C_FLAGS_<CONFIG> on the GCC command
# line, so this -O3 wins over the global -Og/-O2. The library is opaque to
# step-through debugging in practice anyway.
# Use $<COMPILE_LANGUAGE:C> guard so this never leaks onto ASM if upstream
# CMSIS-DSP ever adds .S sources.
target_compile_options(CMSISDSP PRIVATE $<$<COMPILE_LANGUAGE:C>:-O3>)

# Order matters: mx-generated.cmake already appended `m` (libm) earlier via
# TOOLCHAIN_LINK_LIBRARIES, so the link line is `... m CMSISDSP`. CMSIS-DSP
# references libm symbols (sqrtf/cosf/expf/...); the static linker only
# scans left-to-right, so we re-append `m` AFTER CMSISDSP to resolve them.
target_link_libraries(${CMAKE_PROJECT_NAME} CMSISDSP m)

# Silence HAL-only warnings. HAL source has many unused parameters and
# missing-field-initializers by design; we don't want those drowning out
# real warnings from application code. Application code (added via
# target_sources on ${CMAKE_PROJECT_NAME}) is unaffected.
target_compile_options(STM32_Drivers PRIVATE
    -Wno-unused-parameter
    -Wno-missing-field-initializers
    -Wno-undef    # HAL uses `#if FLAG == 1U` on undefined flags by design
)

# Remove wrong libob.a library dependency when using cpp files
list(REMOVE_ITEM CMAKE_C_IMPLICIT_LINK_LIBRARIES ob)

# Validate that STM32CubeMX code is compatible with C standard
if((CMAKE_C_STANDARD EQUAL 90) OR (CMAKE_C_STANDARD EQUAL 99))
    message(ERROR "Generated code requires C11 or higher")
endif()







