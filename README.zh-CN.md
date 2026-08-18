# STM32H745ZIT6 双核模板

[English](README.md) | 中文

基于 **STM32H745ZIT6** 的 Cortex-M7 + Cortex-M4 双核 CMake 模板工程。

工程由 **STM32CubeMX 6.18** 生成，再围绕双核启动、HSEM、内存布局、CMSIS-DSP 和 VS Code + J-Link 调试进行了整理，适合作为 STM32H7 双核项目的起始模板。

## 工程内容

- CM7 / CM4 双核心独立工程和链接脚本；
- 基于 `HSEM_0` 的双核启动握手；
- CM7 侧接入 CMSIS-DSP 1.17.0，CM4 不重复链接 DSP；
- 自定义共享内存、DMA 缓冲区、AXI RAM、ITCM 和备份 SRAM 段；
- 顶层 CMake 统一构建两个核心，支持 Debug / Release；
- VS Code + J-Link 的 CM7、CM4 和双核调试配置；
- 保留 `Project.ioc`，便于继续使用 STM32CubeMX 修改基础配置。

当前工程只提供双核模板和启动框架，没有预置具体业务功能。可以在此基础上添加外设驱动、双核通信协议、实时控制或 DSP 算法。

## 目录结构

下面列出仓库中与开发直接相关的目录和文件；`build/` 目录属于构建产物，不纳入版本控制。

```text
.
├── CM7/                              Cortex-M7 工程
│   ├── Core/
│   │   ├── Inc/                      头文件、HAL 配置和中断声明
│   │   ├── Src/                      主函数、HAL MSP、中断和系统调用
│   │   └── Startup/                  CM7 启动文件
│   ├── Linker/                       CM7 Flash / SRAM 链接脚本
│   ├── .settings/                    CM7 的 STM32Cube / Eclipse 工程设置
│   ├── CMakeLists.txt                CM7 CMake 工程配置
│   ├── CMakePresets.json             CM7 独立构建预设
│   └── mx-generated.cmake            CubeMX 生成的 CM7 构建片段
│
├── CM4/                              Cortex-M4 工程
│   ├── Core/
│   │   ├── Inc/                      头文件、HAL 配置和中断声明
│   │   ├── Src/                      主函数、HAL MSP、中断和系统调用
│   │   └── Startup/                  CM4 启动文件
│   ├── Linker/                       CM4 Flash / SRAM 链接脚本
│   ├── .settings/                    CM4 的 STM32Cube / Eclipse 工程设置
│   ├── CMakeLists.txt                CM4 CMake 工程配置
│   ├── CMakePresets.json             CM4 独立构建预设
│   └── mx-generated.cmake            CubeMX 生成的 CM4 构建片段
│
├── Common/
│   └── Src/                          双核共用的启动代码
│
├── Drivers/
│   ├── CMSIS/                        CMSIS 核心头文件和设备头文件
│   ├── CMSIS-DSP/                    CM7 使用的 CMSIS-DSP 源码和配置
│   └── STM32H7xx_HAL_Driver/         STM32H7 HAL 驱动源码
│
├── cmake/
│   ├── generated/
│   │   └── mx-generated.cmake        顶层构建双核 ExternalProject 配置
│   └── toolchains/
│       ├── gcc-arm-none-eabi.cmake   ARM GNU 工具链配置
│       └── starm-clang.cmake          备用 Starm-Clang 工具链配置
│
├── .vscode/
│   ├── c_cpp_properties.json         VS Code 代码索引配置
│   ├── launch.json                   J-Link 单核 / 双核调试配置
│   └── settings.json                 STM32Cube VS Code 工具配置
├── .settings/                        STM32Cube / Eclipse 相关工程设置
├── .clangd                           clangd 代码分析配置
├── .gitattributes                    文本文件编码和换行约定
├── .gitignore                        构建产物和 CubeMX 重复文件排除规则
├── .mxproject                        STM32CubeMX 工程辅助文件
├── AGENTS.md                         工程约定、内存布局和维护说明
├── CMakeLists.txt                    顶层双核 CMake 入口
├── CMakePresets.json                 顶层 Debug / Release 构建预设
├── Project.ioc                       STM32CubeMX 主配置文件
└── README.md                         工程说明
```

两个核心的 `Core/`、`Startup/`、`Linker/` 和 CMake 文件彼此独立；`Common/` 用于放置双核共用代码；`Drivers/` 保存当前工程需要的 HAL、CMSIS 和 CMSIS-DSP 源码。

## STM32CubeMX 配置基线

工程基于以下配置生成和验证。复用到其他 STM32H745ZIT6 板卡前，应先根据原理图和 Option Bytes 重新确认电源、时钟、启动方式和 Flash 地址。

### 电源、启动与时钟

| 配置项 | 当前工程值 |
| --- | --- |
| Supply Source | `PWR_SMPS_1V8_SUPPLIES_LDO` |
| Voltage Scale | `PWR_REGULATOR_VOLTAGE_SCALE0` |
| HSE | 24 MHz，External Oscillator |
| PLL 输入源 | HSE |
| 系统时钟源 | PLL |
| Cortex-M7 | 480 MHz |
| Cortex-M4 | 240 MHz |
| HCLK | 240 MHz |
| APB 相关总线 | 120 MHz |
| Boot | `BCM7=1`、`BCM4=1` |

### Cache、MPU 和 HSEM

- CM7 I-Cache / D-Cache 已启用；
- CM7 使用 MPU Region 0、1、2，其中 Region 1 覆盖 32 KB DMA 缓冲区，Region 2 覆盖 16 KB 双核共享 RAM；
- CubeMX 已启用 CM7 `HSEM1_IRQn` 和 CM4 `HSEM2_IRQn`；这里的 `1/2` 表示 CPU 中断线，不是 semaphore ID；
- `Project.ioc` 中的 `HeapSize` 和 `StackSize` 均为 CM7、CM4 各 4 KB：

```text
ProjectManager.HeapSize  = M4-0x1000, M7-0x1000
ProjectManager.StackSize = M4-0x1000, M7-0x1000
```

修改 CubeMX 的堆栈大小后，还要同步检查 CM7、CM4 的链接脚本和最终构建结果。

## 基于 STM32CubeMX 的改编

本工程保留 CubeMX 生成的 HAL、启动文件和基础工程结构，主要改编集中在以下部分：

1. **双核构建入口**：顶层 `CMakeLists.txt` 通过 `cmake/generated/mx-generated.cmake` 调用 CM7、CM4 两个独立的 CMake 子工程；根目录 `CMakePresets.json` 提供统一的 Debug / Release 配置。
2. **双核启动流程**：CM4 复位后进入等待状态，CM7 完成时钟初始化后释放 `HSEM_0` 唤醒 CM4；CM4 唤醒后先执行 `SystemCoreClockUpdate()`，再继续 HAL 初始化。
3. **内存布局**：两核分别使用独立 Flash 和私有 RAM，同时约定 `.ram_shared`、`.dma_buffer`、`.axi_ram`、`.itcm`、`.ram_d3` 和 `.backup_sram` 等 section。
4. **CMSIS-DSP 接入**：`CM7/CMakeLists.txt` 构建并链接 `Drivers/CMSIS-DSP`，使用 Cortex-M7 硬件浮点配置；CM4 保持轻量，不链接 DSP 库。
5. **调试流程**：`.vscode/launch.json` 提供基于 J-Link 的 CM7、CM4 单核调试和 `Debug Dual-Core` 双核调试组合配置。
6. **堆栈和链接脚本**：在 CubeMX 基础上同步维护两个核心的堆、栈、Flash 起始地址和自定义内存段，避免只修改 IOC 而遗漏链接脚本。

## 硬件与软件环境

### 硬件

- MCU：STM32H745ZIT6，LQFP144；
- 外部高速时钟：24 MHz HSE；
- 调试接口：SWD，建议使用 ST-LINK 或 SEGGER J-Link；
- CM7 / CM4：480 MHz / 240 MHz。

### 软件

| 工具 | 版本 / 说明 |
| --- | --- |
| STM32CubeMX | 6.18 |
| STM32CubeH7 | 1.13.0 |
| CMSIS-DSP | 1.17.0，仅 CM7 使用 |
| ARM GNU Toolchain | `arm-none-eabi-gcc` 14.3.1 |
| CMake | 4.3.1，最低要求见各 CMakeLists |
| Ninja | 1.13.2 |
| VS Code | 配合 STM32Cube VS Code 扩展 |
| SEGGER J-Link | 用于 VS Code 调试 |

## 快速开始

### 1. 准备工具

安装 STM32CubeMX、ARM GNU Toolchain、CMake、Ninja 和 VS Code。使用 STM32Cube VS Code 扩展时，可以直接使用 STM32Cube 统一安装的工具。

如果工具已由 STM32Cube 安装到默认目录，可在 PowerShell 中临时加入环境变量：

```powershell
$Bundle = "$env:LOCALAPPDATA\stm32cube\bundles"
$env:PATH = "$Bundle\cmake\4.3.1+st.1\bin;$Bundle\ninja\1.13.2+st.1\bin;$Bundle\gnu-tools-for-stm32\14.3.1+st.2\bin;$env:PATH"
```

### 2. 配置和构建

在仓库根目录执行：

```powershell
# Debug
cmake --preset Debug
cmake --build build/Debug --parallel 4

# Release
cmake --preset Release
cmake --build build/Release --parallel 4
```

顶层工程会分别构建两个核心，输出文件为：

```text
CM7/build/Project_CM7.elf
CM4/build/Project_CM4.elf
```

Debug 和 Release 共用 `CM7/build/`、`CM4/build/` 两个核心输出目录。切换配置前建议清理：

```powershell
Remove-Item -Recurse -Force build, CM7\build, CM4\build -ErrorAction SilentlyContinue
```

### 3. 下载程序

使用 ST-LINK 或兼容 SWD 调试器连接目标板，并安装 STM32CubeProgrammer：

```powershell
STM32_Programmer_CLI -c port=SWD -w CM7/build/Project_CM7.elf -v
STM32_Programmer_CLI -c port=SWD -w CM4/build/Project_CM4.elf -v
STM32_Programmer_CLI -c port=SWD -rst
```

双核运行时需要同时下载 CM7 和 CM4 镜像。

## 双核启动与 HSEM

模板中的启动关系如下：

1. CM4 复位后进入等待状态；
2. CM7 初始化系统时钟和自身运行环境；
3. CM7 释放 `HSEM_0`，唤醒 CM4；
4. CM4 被唤醒后调用 `SystemCoreClockUpdate()`，再继续执行 `HAL_Init()` 和应用代码。

`HSEM_0` 只用于启动握手，应用层通信应使用其他 semaphore ID，或使用 `.ram_shared` 配合 HSEM / IPCC 设计通信协议。共享数据还需要考虑 `__DMB()`、Cache 一致性和通知顺序；`volatile` 本身不是同步原语。

## 内存布局

| 区域 | CM7 地址 | CM4 地址 | 大小 | 用途 |
| --- | ---: | ---: | ---: | --- |
| CM7 Flash | `0x08000000` | - | 1 MB | CM7 程序和只读数据 |
| CM4 Flash | - | `0x08100000` | 1 MB | CM4 程序和只读数据 |
| ITCMRAM | `0x00000000` | - | 64 KB | CM7 高速代码，`.itcm` |
| CM7 DTCMRAM | `0x20000000` | - | 128 KB | CM7 默认 RAM |
| CM4 D2 SRAM | - | `0x10000000` | 272 KB | CM4 默认私有 RAM |
| RAM_AXI | `0x24000000` | `0x24000000` | 480 KB | `.axi_ram`，Cacheable 数据 |
| RAM_DMA | `0x24078000` | `0x24078000` | 32 KB | `.dma_buffer`，Non-Cacheable DMA 缓冲区 |
| RAM_SHARED | `0x30044000` | `0x10044000` alias | 16 KB | `.ram_shared`，双核共享数据 |
| RAM_D3 | `0x38000000` | `0x38000000` | 64 KB | `.ram_d3`，D3 域和 BDMA 可访问区域 |
| BACKUP_SRAM | `0x38800000` | `0x38800000` | 4 KB | `.backup_sram`，备份域数据 |

使用自定义 section 时，示例：

```c
__attribute__((section(".dma_buffer"), aligned(32))) uint8_t dma_buf[1024];
__attribute__((section(".axi_ram"), aligned(32))) uint8_t framebuf[256 * 1024];
__attribute__((section(".itcm"))) void hot_func(void) { }
__attribute__((section(".ram_shared"))) volatile uint32_t shared_word;
```

DMA 缓冲区应按 32 字节对齐；DMA1/2/BDMA 不能访问 DTCM，BDMA 缓冲区应放在 `.ram_d3`。除 `.itcm` 外，自定义 RAM section 通常为 `NOLOAD`，使用前需要由应用自行初始化。更完整的 Cache、MPU 和内存约定见 [`AGENTS.md`](AGENTS.md)。

## VS Code + J-Link 调试

`.vscode/launch.json` 使用 STM32Cube VS Code 扩展提供的 `jlinkgdbtarget` 调试类型，目标芯片为 `STM32H745ZIT6`，通过 SWD 连接，调试速度为 4000 kHz。

### 调试准备

1. 安装 VS Code 和 STM32Cube VS Code 扩展；
2. 安装 SEGGER J-Link 软件及驱动；
3. 使用 J-Link 连接目标板的 SWD 接口；
4. 先完成 Debug 构建，确认以下 ELF 文件存在：

```text
CM7/build/Project_CM7.elf
CM4/build/Project_CM4.elf
```

### 调试配置

在 VS Code 的“运行和调试”面板中可以选择：

- **Debug CM7**：以 Cortex-M7 为当前调试核心，同时加载两个核心的 ELF 符号；
- **Debug CM4**：以 Cortex-M4 为当前调试核心，同时加载两个核心的 ELF 符号；
- **Debug Dual-Core**：启动 CM7 后，再附加到 CM4，适合观察双核启动和 HSEM 流程。

双核调试时，CM4 需要等待 CM7 释放 `HSEM_0`。如果只调试单个核心，应根据 `CM7/CMakeLists.txt` 或 `CM4/CMakeLists.txt` 中的注释处理 `DUAL_CORE_BOOT_SYNC_SEQUENCE`，并确保下载了对应的核心镜像。

## 使用 STM32CubeMX 重新生成

打开 [`Project.ioc`](Project.ioc) 可以查看或修改 CubeMX 配置。重新生成后，重点检查：

- HSE、电源模式、主频、Boot 和两个核心的 Flash 起始地址；
- CM7 的 I-Cache、D-Cache 和 MPU Region 1 / 2；
- CM7 `HSEM1_IRQn`、CM4 `HSEM2_IRQn` 以及双核启动握手；
- 两个核心的堆栈大小和链接脚本；
- `Drivers/CMSIS-DSP/` 是否仍只链接到 CM7；
- `Common/`、自定义链接脚本和两核 `CMakeLists.txt` 是否保留。

建议重新生成后立即检查：

```powershell
git diff
git status
```

CubeMX 可能在根目录或核心目录生成重复的 toolchain、`mx-generated.cmake` 和链接脚本。模板实际使用的是：

- `cmake/toolchains/`；
- `cmake/generated/mx-generated.cmake`；
- `CM7/Linker/`；
- `CM4/Linker/`。

确认内容后，删除或忽略重复生成文件，再重新构建两个核心。

## 推荐阅读顺序

1. 阅读 [`Project.ioc`](Project.ioc)，了解芯片、电源、时钟和双核配置；
2. 阅读 [`CMakeLists.txt`](CMakeLists.txt) 与 [`CMakePresets.json`](CMakePresets.json)，了解顶层构建关系；
3. 阅读 `CM7/Core/Src/main.c`，理解 CM7 初始化和释放 HSEM 的流程；
4. 阅读 `CM4/Core/Src/main.c`，理解 CM4 等待和唤醒流程；
5. 阅读 `CM7/Linker/`、`CM4/Linker/`，理解 Flash、私有 RAM 和共享 RAM 的分配；
6. 阅读 [`AGENTS.md`](AGENTS.md)，再开始添加应用代码或修改内存布局。

## 版本控制范围

仓库保留源码、CubeMX 配置、CMake 配置、启动文件、链接脚本、HAL/CMSIS/CMSIS-DSP 源码及其随附许可证文件。

以下内容不应提交：

- 根目录、`CM7/`、`CM4/` 下的 `build/`；
- 编译缓存、`compile_commands.json` 等本地生成文件；
- CubeMX 在当前模板之外生成的重复 toolchain、链接脚本和 `mx-generated.cmake`。
