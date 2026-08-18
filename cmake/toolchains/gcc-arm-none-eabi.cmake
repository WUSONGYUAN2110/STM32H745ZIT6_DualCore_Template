include_guard(GLOBAL)

set(CMAKE_SYSTEM_NAME               Generic)
set(CMAKE_SYSTEM_PROCESSOR          arm)

# Some default GCC settings
# arm-none-eabi- must be part of path environment
set(TOOLCHAIN_PREFIX                arm-none-eabi-)

set(CMAKE_C_COMPILER                ${TOOLCHAIN_PREFIX}gcc)
set(CMAKE_ASM_COMPILER              ${CMAKE_C_COMPILER})
set(CMAKE_CXX_COMPILER              ${TOOLCHAIN_PREFIX}g++)
set(CMAKE_LINKER                    ${TOOLCHAIN_PREFIX}g++)
set(CMAKE_OBJCOPY                   ${TOOLCHAIN_PREFIX}objcopy)
set(CMAKE_SIZE                      ${TOOLCHAIN_PREFIX}size)

set(CMAKE_EXECUTABLE_SUFFIX_ASM     ".elf")
set(CMAKE_EXECUTABLE_SUFFIX_C       ".elf")
set(CMAKE_EXECUTABLE_SUFFIX_CXX     ".elf")

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# MCU specific flags
set(TARGET_FLAGS "${STM32_MCU_FLAGS}")

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${TARGET_FLAGS}")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wextra -Wundef -Wdouble-promotion")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fdata-sections -ffunction-sections -fstack-usage")
# Note: -Wshadow is intentionally OFF — HAL headers shadow common identifiers
# (e.g. tmpreg in macros) and would flood the build log. Enable per-target on
# application code only if you want shadow checking.
# -Wdouble-promotion is especially valuable for DSP work on M7 FPv5-D16:
# the FPU is single-precision only, so accidental float→double promotion
# (e.g. `float x = sinf(y) + 1.0;` where 1.0 is double) silently emits
# software-emulated double arithmetic and tanks performance.
set(CMAKE_ASM_FLAGS "${CMAKE_C_FLAGS} -x assembler-with-cpp -MMD -MP")

# The cyclomatic-complexity parameter must be defined for the Cyclomatic complexity feature in STM32CubeIDE to work.
# However, most GCC toolchains do not support this option, which causes a compilation error; for this reason, the feature is disabled by default.
# set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fcyclomatic-complexity")

# Debug: -Og keeps stepping/variable inspection usable while avoiding the
# 5-10x slowdown of -O0 on float code (M7 FPU is heavily reg-pressured at
# -O0) and the stack-blow-up risk that -O0 brings on complex DSP routines.
# -O0 silently hides dataflow warnings (-Wuninitialized etc.) too.
set(CMAKE_C_FLAGS_DEBUG "-Og -g3")

# Release: -O2 is the embedded sweet spot. -O3 buys ~5-15% on tight DSP loops
# but bloats ICache footprint (M7 ICache is only 16KB) and triggers vectorize
# passes that produce nothing useful on FPv5-D16 (scalar FPU, no NEON).
# -Os was the previous value; for a DSP template the size win (H745 has 2MB
# Flash anyway) isn't worth losing inlining + scheduling + unrolling.
# CMSIS-DSP itself is still forced to -O3 in CM7/CMakeLists.txt.
#
# -g3 stays in Release intentionally: DWARF sections don't load to Flash
# (link script has no `>FLASH` on .debug_*), so debug info is free at runtime.
# Keeping it means a Release elf attached via ST-Link still shows function
# names and source lines for field debugging / HardFault triage.
set(CMAKE_C_FLAGS_RELEASE "-O2 -g3")

set(CMAKE_CXX_FLAGS_DEBUG "-Og -g3")
set(CMAKE_CXX_FLAGS_RELEASE "-O2 -g3")

set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -fno-rtti -fno-exceptions -fno-threadsafe-statics")

# CMake already applies CMAKE_<LANG>_FLAGS (including TARGET_FLAGS) when linking.
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -T \"${CMAKE_SOURCE_DIR}/${STM32_LINKER_SCRIPT}\"")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} --specs=nano.specs")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,-Map=${CMAKE_PROJECT_NAME}.map -Wl,--gc-sections")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--print-memory-usage")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${STM32_LINKER_OPTION}")
set(TOOLCHAIN_LINK_LIBRARIES "m")
