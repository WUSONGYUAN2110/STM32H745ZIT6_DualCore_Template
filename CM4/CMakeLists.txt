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
set(STM32_MCU_FLAGS  "-mcpu=cortex-m4 -mfpu=fpv4-sp-d16 -mfloat-abi=hard" )

#Linker options
set(STM32_LINKER_SCRIPT Linker/stm32h745xx_flash_CM4.ld)
set(STM32_LINKER_OPTION  )

# Set the project name
set(CMAKE_PROJECT_NAME Project_CM4)
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
    # Keep defined for normal dual-core boot: CM4 enters STOP at reset and waits
    # for CM7 to release HSEM_0 after clock config (otherwise CM4 would run at
    # HSI 64 MHz with stale SystemCoreClock).
    # Comment out ONLY when debugging CM4 alone with no CM7 image flashed —
    # then CM4 will skip the STOP/HSEM wait and run free at HSI.
    DUAL_CORE_BOOT_SYNC_SEQUENCE
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







