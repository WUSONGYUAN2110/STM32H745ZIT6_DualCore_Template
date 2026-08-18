# STM32H745ZIT6 Dual-Core Template

English | [中文](README.zh-CN.md)

A CMake template for the **STM32H745ZIT6** Cortex-M7 + Cortex-M4 dual-core MCU.

The project was generated with **STM32CubeMX 6.18** and then organized around dual-core boot, HSEM, memory layout, CMSIS-DSP, and VS Code + J-Link debugging. It is intended as a starting point for STM32H7 dual-core projects.

## Included

- Independent CM7 and CM4 projects and linker scripts;
- Dual-core boot handshake based on `HSEM_0`;
- CMSIS-DSP 1.17.0 linked only to CM7, without a duplicate CM4 copy;
- Custom sections for shared memory, DMA buffers, AXI RAM, ITCM, and backup SRAM;
- A top-level CMake build for both cores with Debug and Release configurations;
- VS Code + J-Link configurations for CM7, CM4, and dual-core debugging;
- The original `Project.ioc` for continued STM32CubeMX configuration.

The repository provides a dual-core template and boot framework without application-specific behavior. Peripheral drivers, inter-core protocols, real-time control, or DSP algorithms can be added on top of it.

## Project structure

The following tree lists files and directories directly relevant to development. Generated `build/` directories are excluded from version control.

```text
.
├── CM7/                              Cortex-M7 project
│   ├── Core/
│   │   ├── Inc/                      Headers, HAL configuration, and interrupt declarations
│   │   ├── Src/                      Main, HAL MSP, interrupts, and system calls
│   │   └── Startup/                  CM7 startup file
│   ├── Linker/                       CM7 Flash/SRAM linker scripts
│   ├── .settings/                    CM7 STM32Cube/Eclipse settings
│   ├── CMakeLists.txt                CM7 CMake project
│   ├── CMakePresets.json             CM7 standalone build presets
│   └── mx-generated.cmake            CubeMX-generated CM7 build fragment
│
├── CM4/                              Cortex-M4 project
│   ├── Core/
│   │   ├── Inc/                      Headers, HAL configuration, and interrupt declarations
│   │   ├── Src/                      Main, HAL MSP, interrupts, and system calls
│   │   └── Startup/                  CM4 startup file
│   ├── Linker/                       CM4 Flash/SRAM linker scripts
│   ├── .settings/                    CM4 STM32Cube/Eclipse settings
│   ├── CMakeLists.txt                CM4 CMake project
│   ├── CMakePresets.json             CM4 standalone build presets
│   └── mx-generated.cmake            CubeMX-generated CM4 build fragment
│
├── Common/
│   └── Src/                          Startup code shared by both cores
│
├── Drivers/
│   ├── CMSIS/                        CMSIS core and device headers
│   ├── CMSIS-DSP/                    CMSIS-DSP source and configuration used by CM7
│   └── STM32H7xx_HAL_Driver/         STM32H7 HAL driver source
│
├── cmake/
│   ├── generated/
│   │   └── mx-generated.cmake        Top-level ExternalProject configuration for both cores
│   └── toolchains/
│       ├── gcc-arm-none-eabi.cmake   ARM GNU toolchain configuration
│       └── starm-clang.cmake          Alternative Starm-Clang toolchain configuration
│
├── .vscode/
│   ├── c_cpp_properties.json         VS Code code-index configuration
│   ├── launch.json                   J-Link single-core and dual-core debug configurations
│   └── settings.json                 STM32Cube VS Code tool configuration
├── .settings/                        STM32Cube/Eclipse project settings
├── .clangd                           clangd analysis configuration
├── .gitattributes                    Text encoding and line-ending rules
├── .gitignore                        Build and duplicate CubeMX file exclusions
├── .mxproject                        STM32CubeMX project helper file
├── AGENTS.md                         Project rules, memory map, and maintenance notes
├── CMakeLists.txt                    Top-level dual-core CMake entry point
├── CMakePresets.json                 Top-level Debug/Release presets
├── Project.ioc                       Main STM32CubeMX configuration
└── README.md                         Project documentation
```

The `Core/`, `Startup/`, `Linker/`, and CMake files are independent for each core. `Common/` contains code shared by both cores, while `Drivers/` contains the HAL, CMSIS, and CMSIS-DSP sources required by the project.

## STM32CubeMX baseline

The project was generated and validated with the following configuration. Before reusing it on another STM32H745ZIT6 board, verify the power, clock, boot mode, and Flash addresses against the schematic and Option Bytes.

### Power, boot, and clock

| Setting | Current value |
| --- | --- |
| Supply Source | `PWR_SMPS_1V8_SUPPLIES_LDO` |
| Voltage Scale | `PWR_REGULATOR_VOLTAGE_SCALE0` |
| HSE | 24 MHz, External Oscillator |
| PLL source | HSE |
| System clock source | PLL |
| Cortex-M7 | 480 MHz |
| Cortex-M4 | 240 MHz |
| HCLK | 240 MHz |
| APB-related buses | 120 MHz |
| Boot | `BCM7=1`, `BCM4=1` |

### Cache, MPU, and HSEM

- CM7 I-Cache and D-Cache are enabled.
- CM7 uses MPU Regions 0, 1, and 2. Region 1 covers the 32 KB DMA buffer, and Region 2 covers the 16 KB dual-core shared RAM.
- CubeMX enables CM7 `HSEM1_IRQn` and CM4 `HSEM2_IRQn`; `1/2` identifies the CPU interrupt line, not the semaphore ID.
- `HeapSize` and `StackSize` in `Project.ioc` are both 4 KB for CM7 and CM4:

```text
ProjectManager.HeapSize  = M4-0x1000, M7-0x1000
ProjectManager.StackSize = M4-0x1000, M7-0x1000
```

After changing heap or stack sizes in CubeMX, check both linker scripts and the final build results as well.

## Adaptations from STM32CubeMX

The project retains the HAL, startup files, and base structure generated by CubeMX. The main adaptations are:

1. **Dual-core build entry point**: the top-level `CMakeLists.txt` uses `cmake/generated/mx-generated.cmake` to invoke independent CM7 and CM4 CMake projects. The root `CMakePresets.json` provides unified Debug and Release configurations.
2. **Dual-core boot flow**: CM4 waits after reset. CM7 releases `HSEM_0` after clock initialization to wake CM4, which calls `SystemCoreClockUpdate()` before continuing HAL initialization.
3. **Memory layout**: the cores use independent Flash and private RAM while sharing the `.ram_shared`, `.dma_buffer`, `.axi_ram`, `.itcm`, `.ram_d3`, and `.backup_sram` conventions.
4. **CMSIS-DSP integration**: `CM7/CMakeLists.txt` builds and links `Drivers/CMSIS-DSP` with Cortex-M7 hardware floating-point settings. CM4 remains lightweight and does not link the DSP library.
5. **Debug workflow**: `.vscode/launch.json` provides J-Link configurations for CM7, CM4, and a combined `Debug Dual-Core` session.
6. **Heap, stack, and linker scripts**: the heap, stack, Flash origins, and custom memory sections for both cores are maintained together with the CubeMX configuration so the IOC and linker scripts remain consistent.

## Hardware and software environment

### Hardware

- MCU: STM32H745ZIT6, LQFP144;
- External high-speed clock: 24 MHz HSE;
- Debug interface: SWD, with ST-LINK or SEGGER J-Link recommended;
- CM7 / CM4: 480 MHz / 240 MHz.

### Software

| Tool | Version / notes |
| --- | --- |
| STM32CubeMX | 6.18 |
| STM32CubeH7 | 1.13.0 |
| CMSIS-DSP | 1.17.0, CM7 only |
| ARM GNU Toolchain | `arm-none-eabi-gcc` 14.3.1 |
| CMake | 4.3.1; see each CMakeLists for the minimum version |
| Ninja | 1.13.2 |
| VS Code | Used with the STM32Cube VS Code extension |
| SEGGER J-Link | Used for VS Code debugging |

## Quick start

### 1. Prepare the tools

Install STM32CubeMX, ARM GNU Toolchain, CMake, Ninja, and VS Code. When using the STM32Cube VS Code extension, the tools installed through the STM32Cube bundle can be used directly.

If the tools are installed in the default STM32Cube location, add them temporarily to the PowerShell environment:

```powershell
$Bundle = "$env:LOCALAPPDATA\stm32cube\bundles"
$env:PATH = "$Bundle\cmake\4.3.1+st.1\bin;$Bundle\ninja\1.13.2+st.1\bin;$Bundle\gnu-tools-for-stm32\14.3.1+st.2\bin;$env:PATH"
```

### 2. Configure and build

Run these commands from the repository root:

```powershell
# Debug
cmake --preset Debug
cmake --build build/Debug --parallel 4

# Release
cmake --preset Release
cmake --build build/Release --parallel 4
```

The top-level project builds both cores. The output files are:

```text
CM7/build/Project_CM7.elf
CM4/build/Project_CM4.elf
```

Debug and Release share the core output directories `CM7/build/` and `CM4/build/`. Clean before changing configuration:

```powershell
Remove-Item -Recurse -Force build, CM7\build, CM4\build -ErrorAction SilentlyContinue
```

### 3. Program the target

Connect an ST-LINK or compatible SWD probe and install STM32CubeProgrammer:

```powershell
STM32_Programmer_CLI -c port=SWD -w CM7/build/Project_CM7.elf -v
STM32_Programmer_CLI -c port=SWD -w CM4/build/Project_CM4.elf -v
STM32_Programmer_CLI -c port=SWD -rst
```

Both CM7 and CM4 images must be programmed for dual-core operation.

## Dual-core boot and HSEM

The template uses the following boot relationship:

1. CM4 enters a waiting state after reset.
2. CM7 initializes the system clock and its runtime environment.
3. CM7 releases `HSEM_0` to wake CM4.
4. CM4 calls `SystemCoreClockUpdate()` after waking, then continues with `HAL_Init()` and application code.

`HSEM_0` is reserved for the boot handshake. Application communication should use another semaphore ID or a protocol built on `.ram_shared` with HSEM or IPCC. Shared data also requires correct `__DMB()`, cache-coherency, and notification ordering; `volatile` alone is not a synchronization primitive.

## Memory map

| Region | CM7 address | CM4 address | Size | Purpose |
| --- | ---: | ---: | ---: | --- |
| CM7 Flash | `0x08000000` | - | 1 MB | CM7 code and read-only data |
| CM4 Flash | - | `0x08100000` | 1 MB | CM4 code and read-only data |
| ITCMRAM | `0x00000000` | - | 64 KB | CM7 high-speed code, `.itcm` |
| CM7 DTCMRAM | `0x20000000` | - | 128 KB | Default CM7 RAM |
| CM4 D2 SRAM | - | `0x10000000` | 272 KB | Default private CM4 RAM |
| RAM_AXI | `0x24000000` | `0x24000000` | 480 KB | Cacheable `.axi_ram` data |
| RAM_DMA | `0x24078000` | `0x24078000` | 32 KB | Non-cacheable `.dma_buffer` DMA buffer |
| RAM_SHARED | `0x30044000` | `0x10044000` alias | 16 KB | Dual-core shared `.ram_shared` data |
| RAM_D3 | `0x38000000` | `0x38000000` | 64 KB | `.ram_d3`, accessible by the D3 domain and BDMA |
| BACKUP_SRAM | `0x38800000` | `0x38800000` | 4 KB | Backup-domain `.backup_sram` data |

Example custom sections:

```c
__attribute__((section(".dma_buffer"), aligned(32))) uint8_t dma_buf[1024];
__attribute__((section(".axi_ram"), aligned(32))) uint8_t framebuf[256 * 1024];
__attribute__((section(".itcm"))) void hot_func(void) { }
__attribute__((section(".ram_shared"))) volatile uint32_t shared_word;
```

DMA buffers should be aligned to 32 bytes. DMA1/2 and BDMA cannot access DTCM; BDMA buffers should be placed in `.ram_d3`. Except for `.itcm`, custom RAM sections are generally `NOLOAD` and must be initialized by the application before use. See [`AGENTS.md`](AGENTS.md) for the complete cache, MPU, and memory conventions.

## VS Code + J-Link debugging

`.vscode/launch.json` uses the `jlinkgdbtarget` debug type supplied by the STM32Cube VS Code extension. The target is `STM32H745ZIT6`, connected through SWD at 4000 kHz.

### Debug preparation

1. Install VS Code and the STM32Cube VS Code extension.
2. Install SEGGER J-Link software and drivers.
3. Connect J-Link to the target's SWD interface.
4. Complete a Debug build and confirm that these ELF files exist:

```text
CM7/build/Project_CM7.elf
CM4/build/Project_CM4.elf
```

### Debug configurations

The Run and Debug panel provides:

- **Debug CM7**: selects Cortex-M7 as the active core and loads symbols for both cores;
- **Debug CM4**: selects Cortex-M4 as the active core and loads symbols for both cores;
- **Debug Dual-Core**: starts CM7 and then attaches to CM4, which is useful for observing dual-core boot and HSEM behavior.

During dual-core debugging, CM4 waits for CM7 to release `HSEM_0`. For single-core debugging, follow the comments around `DUAL_CORE_BOOT_SYNC_SEQUENCE` in `CM7/CMakeLists.txt` or `CM4/CMakeLists.txt`, and make sure the corresponding core image has been programmed.

## Regenerating with STM32CubeMX

Open [`Project.ioc`](Project.ioc) to inspect or change the CubeMX configuration. After regeneration, verify:

- HSE, power mode, core clocks, Boot settings, and both Flash origins;
- CM7 I-Cache, D-Cache, and MPU Regions 1 and 2;
- CM7 `HSEM1_IRQn`, CM4 `HSEM2_IRQn`, and the dual-core boot handshake;
- Heap and stack sizes and both linker scripts;
- That `Drivers/CMSIS-DSP/` remains linked only to CM7;
- That `Common/`, the custom linker scripts, and both core-specific `CMakeLists.txt` files are preserved.

Review the result immediately after regeneration:

```powershell
git diff
git status
```

CubeMX may generate duplicate toolchain files, `mx-generated.cmake`, and linker scripts in the root or core directories. This template uses:

- `cmake/toolchains/`;
- `cmake/generated/mx-generated.cmake`;
- `CM7/Linker/`;
- `CM4/Linker/`.

After reviewing the content, delete or ignore duplicate generated files and rebuild both cores.

## Recommended reading order

1. Read [`Project.ioc`](Project.ioc) for the device, power, clock, and dual-core configuration.
2. Read [`CMakeLists.txt`](CMakeLists.txt) and [`CMakePresets.json`](CMakePresets.json) for the top-level build relationship.
3. Read `CM7/Core/Src/main.c` for CM7 initialization and HSEM release.
4. Read `CM4/Core/Src/main.c` for the CM4 wait and wake-up flow.
5. Read `CM7/Linker/` and `CM4/Linker/` for Flash, private RAM, and shared RAM allocation.
6. Read [`AGENTS.md`](AGENTS.md) before adding application code or changing the memory layout.

## Version-control scope

The repository keeps source code, CubeMX configuration, CMake configuration, startup files, linker scripts, HAL/CMSIS/CMSIS-DSP sources, and their accompanying license files.

Do not commit:

- `build/` directories in the root, `CM7/`, or `CM4/`;
- Build caches, `compile_commands.json`, or other local generated files;
- Duplicate toolchains, linker scripts, or `mx-generated.cmake` files generated by CubeMX outside the paths used by this template.