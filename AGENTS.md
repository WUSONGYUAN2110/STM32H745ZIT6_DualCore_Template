# STM32H745ZIT6 Dual-Core DSP Template / 双核 DSP 模板

This is a CMake project generated with STM32CubeMX 6.18 for Cortex-M7 and Cortex-M4; CMSIS-DSP is linked only to CM7. This file is the shared entry point for people and AI tools. Treat `Project.ioc`, both linker scripts, and actual build results as the source of truth.

STM32CubeMX 6.18 生成的 CMake 工程：Cortex-M7 + Cortex-M4，CMSIS-DSP 仅接入 CM7。本文件是人和 AI 共用的模板入口；工程事实以 `Project.ioc`、两核链接脚本和实际构建结果为准。

## English quick reference

- Preserve existing work and keep the template minimal. Prefer USER CODE blocks, project-owned files, both core-specific `CMakeLists.txt` files, and `Linker/` when making changes.
- The baseline is STM32H745ZIT6 with a 24 MHz HSE, CM7 at 480 MHz, CM4 at 240 MHz, and separate 1 MB Flash regions starting at `0x08000000` and `0x08100000`.
- Keep DMA buffers in the non-cacheable `.dma_buffer` section, shared dual-core data in `.ram_shared`, and large cacheable data in `.axi_ram`. `volatile` is not a synchronization primitive; use memory barriers and HSEM or IPCC notifications.
- With `DUAL_CORE_BOOT_SYNC_SEQUENCE`, CM4 enters STOP and CM7 releases HSEM_0 after clock setup. Reserve HSEM_0 for boot synchronization and use other semaphore IDs for application traffic.
- Clean all three build directories before switching Debug and Release. Build both configurations from clean directories and program CM7 before CM4.
- CMSIS-DSP 1.17.0 is built only for CM7. After CubeMX regeneration, review clock, power, option bytes, linker origins, cache/MPU settings, boot synchronization, interrupt handlers, and generated duplicates.

## Working principles / 使用原则

- 修改前先看 `git status`；保留已有改动，不使用破坏性 reset/checkout。
- 保持最小模板：没有明确需求时，不引入 RTOS、OpenAMP、固定 mailbox、自动烧录框架或多层封装。
- 优先修改 USER CODE、自建文件、两核 `CMakeLists.txt` 和 `Linker/`；CubeMX 生成区外的手工修改可能被覆盖。
- 改动 HSE、电源、Boot 或内存布局时，必须同步核对 IOC、Option Bytes、两核链接脚本、MPU 和本文档。
- 代码修改后至少构建受影响配置；准备复制模板或提交时删除所有 build 和 CubeMX 重复产物。

主要目录：`CM7/`、`CM4/`、`Common/`、`Drivers/`、`cmake/{generated,toolchains}/`、`Project.ioc`。

## Hardware baseline / 硬件基线

| 项 | 当前值 |
|---|---|
| MCU | STM32H745ZIT6，LQFP144 |
| CubeMX / FW | 6.18 / STM32CubeH7 1.13.0 |
| HSE | 24 MHz |
| 主频 | CM7 480 MHz / CM4 240 MHz |
| 电源 | `PWR_SMPS_1V8_SUPPLIES_LDO` |
| Boot | `BCM7=1`, `BCM4=1` |
| CM7 Flash | `0x08000000`, 1 MB |
| CM4 Flash | `0x08100000`, 1 MB |

复用到新板前必须确认 HSE、电源模式、Option Bytes 和两个 `FLASH ORIGIN` 一致。

## Memory map / 内存布局

| 区域 | CM7 地址 | CM4 地址 | 大小 | 用途 |
|---|---:|---:|---:|---|
| CM7 FLASH | `0x08000000` | - | 1 MB | CM7 `.text/.rodata` |
| CM4 FLASH | - | `0x08100000` | 1 MB | CM4 `.text/.rodata` |
| ITCMRAM | `0x00000000` | - | 64 KB | CM7 `.itcm` |
| CM7 DTCMRAM | `0x20000000` | - | 128 KB | CM7 默认 RAM |
| CM4 D2 SRAM | - | `0x10000000` | 272 KB | CM4 默认私有 RAM |
| RAM_AXI | `0x24000000` | 同地址 | 480 KB | `.axi_ram`，Cacheable |
| RAM_DMA | `0x24078000` | 同地址 | 32 KB | `.dma_buffer`，Non-Cacheable |
| RAM_SHARED | `0x30044000` | `0x10044000` alias | 16 KB | `.ram_shared`，双核共享 |
| RAM_D3 | `0x38000000` | 同地址 | 64 KB | `.ram_d3`，BDMA 可访问 |
| BACKUP_SRAM | `0x38800000` | 同地址 | 4 KB | `.backup_sram` |

CM7 不使用 `0x30000000..0x30043FFF`，该物理 D2 SRAM 由 CM4 通过 `0x10000000` alias 私有使用。DMA1/2/BDMA 不能访问 DTCM，MDMA 可以；BDMA buffer 放 `.ram_d3`。

```c
__attribute__((section(".dma_buffer"), aligned(32))) uint8_t dma_buf[1024];
__attribute__((section(".axi_ram"), aligned(32))) uint8_t framebuf[256 * 1024];
__attribute__((section(".itcm"))) void hot_func(void) { }
__attribute__((section(".ram_shared"))) volatile uint32_t shared_word;
__attribute__((section(".backup_sram"))) uint32_t boot_counter;
```

除 `.itcm` 外，上述自定义 RAM section 均为 `NOLOAD`，使用前自行初始化。Backup SRAM 还需开启 BKPRAM 时钟、备份域写访问和 Backup Regulator。

## Cache, MPU, and dual-core conventions / Cache、MPU 和双核约定

CM7 顺序：`MPU_Config()` → `SCB_EnableICache()` → `SCB_EnableDCache()`。

| MPU Region | 范围 | 属性 |
|---|---|---|
| 0 | `0x60000000..0xDFFFFFFF` | 外部地址推测访问保护 |
| 1 | `0x24078000`, 32 KB | Normal Non-Cacheable |
| 2 | `0x30044000`, 16 KB | Normal Non-Cacheable, Shareable |

- DMA buffer 放 `.dma_buffer` 并按 32 字节对齐；其他 Cacheable RAM 做 DMA 时自行维护 D-Cache。
- 共享数据放 `.ram_shared`；`volatile` 不是同步原语，发布/读取需要 `__DMB()` 和 HSEM/IPCC 等通知。
- 两个 ELF 独立链接，共享结构必须由公共定义保证布局一致。

## Dual-core boot and HSEM / 双核启动与 HSEM

- 正常双核启动定义 `DUAL_CORE_BOOT_SYNC_SEQUENCE`：CM4 进入 STOP，CM7 配置时钟后释放 HSEM_0 唤醒 CM4。
- CM4 唤醒后必须调用 `SystemCoreClockUpdate()`，再执行 `HAL_Init()`。
- HSEM_0 仅用于启动；应用通信使用其他 semaphore ID。
- IOC 已启用 CM7 `HSEM1_IRQn` 和 CM4 `HSEM2_IRQn`。这里的 1/2 表示 CPU 中断线，不是 semaphore ID。
- 模板不预置应用协议。实际项目可用 `.ram_shared` mailbox + HSEM；发送方写数据后 `__DMB()` 再释放，接收回调先 `__DMB()` 再读，并重新调用 `HAL_HSEM_ActivateNotification()`。
- 单核调试时，注释对应核 `CMakeLists.txt` 中的 `DUAL_CORE_BOOT_SYNC_SEQUENCE`。

## Build and program / 构建与烧录

优先使用 STM32Cube VS Code 扩展：`CMake: Select Configure Preset` → `CMake: Build`。`.vscode/settings.json` 已绑定 Cube bundle。普通 PowerShell 可先设置：

```powershell
$Bundle = "$env:LOCALAPPDATA\stm32cube\bundles"
$env:PATH = "$Bundle\cmake\4.3.1+st.1\bin;$Bundle\ninja\1.13.2+st.1\bin;$Bundle\gnu-tools-for-stm32\14.3.1+st.2\bin;$env:PATH"
```

Debug/Release 共用两核输出目录，会互相覆盖；切换配置前清理：

```powershell
$Config = "Debug" # 或 Release
Remove-Item -Recurse -Force build, CM7\build, CM4\build -ErrorAction SilentlyContinue
cmake --preset $Config
cmake --build "build/$Config"
```

产物固定为 `CM7/build/Project_CM7.elf` 和 `CM4/build/Project_CM4.elf`。

```powershell
STM32_Programmer_CLI -c port=SWD -w CM7/build/Project_CM7.elf -v
STM32_Programmer_CLI -c port=SWD -w CM4/build/Project_CM4.elf -v
STM32_Programmer_CLI -c port=SWD -rst
```

## CMSIS-DSP

- 版本 1.17.0，仅由 [CM7/CMakeLists.txt](CM7/CMakeLists.txt) 构建。
- `DISABLEFLOAT16=ON`、`FASTBUILD=ON`、`LOOPUNROLL=ON`，库强制 `-O3`。
- CM7 使用 `-mcpu=cortex-m7 -mfpu=fpv5-d16 -mfloat-abi=hard`；未使用函数由 `--gc-sections` 裁剪。
- DSP 浮点常量使用 `f` 后缀；大数组放 `.axi_ram`，DMA buffer 放 `.dma_buffer`，不要放 DTCM。
- 仓库仅保留嵌入式构建所需的 Source、头文件、可选后端、许可证和版本信息。

## CubeMX regeneration / CubeMX 重新生成

会覆盖：两核 `mx-generated.cmake`、生成代码 USER CODE 块外内容、头文件、Startup，以及链接脚本的 heap/stack 设置。不会覆盖：USER CODE、自建 `Common` 文件、两核 `CMakeLists.txt`、`Drivers/CMSIS-DSP/` 和链接脚本自定义主体。

重新生成后执行 `git diff`，重点核对：

- HSE、电源、主频、Option Bytes 和 Flash 起点；
- I/D-Cache、MPU Region 1/2；
- 双核启动序列、CM7 `.itcm` 搬运、CM4 `SystemCoreClockUpdate()`；
- CM7 `HSEM1_IRQHandler()`、CM4 `HSEM2_IRQHandler()`；
- CMSIS-DSP 仍只链接 CM7。

CubeMX 会额外生成被 `.gitignore` 忽略的根目录 toolchain/`mx-generated.cmake` 和两核根目录链接脚本。模板以 `cmake/{generated,toolchains}` 和两核 `Linker/` 为准；复制或提交前删除重复文件及三个 build 目录。

## Minimum acceptance checks / 最小验收

1. Debug 和 Release 均能从干净目录构建。
2. 两核 ELF 的 Flash/RAM 地址、CPU/FPU 属性符合本文件。
3. `compile_commands.json` 中 CM7/CM4 flags 正确且不重复，CMSIS-DSP 仅出现于 CM7。
4. 模板最终不包含 build、缓存和 CubeMX 重复产物，`git status` 干净。

```powershell
arm-none-eabi-readelf -A CM7/build/Project_CM7.elf | Select-String "CPU_name|FP_arch|ABI_VFP_args"
arm-none-eabi-readelf -A CM4/build/Project_CM4.elf | Select-String "CPU_name|FP_arch|ABI_VFP_args"
```
