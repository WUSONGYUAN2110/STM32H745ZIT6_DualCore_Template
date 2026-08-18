/*
******************************************************************************
**
**  File        : stm32h745xx_flash_CM7.ld
**  Target      : STM32H745ZIT6 - Cortex-M7 core
**
**  Memory map  : 2MB Flash (Bank1+Bank2) / 1MB SRAM total
**                CM7 boots from Flash Bank1 @ 0x08000000
**
**  All on-chip memory regions are declared in MEMORY below so application
**  code can target any region via __attribute__((section(".<name>"))).
**  See AGENTS.md for the section names and intended usage.
**
**  Distribution: AS-IS, no warranty.
**
******************************************************************************
*/

ENTRY(Reset_Handler)

/* ===========================================================================
 * Memory regions (CM7 view)
 *
 *   FLASH       Bank1, CM7 code/rodata
 *   ITCMRAM     Tightly-coupled instruction RAM (zero-wait code execution)
 *   DTCMRAM     Tightly-coupled data RAM (zero-wait data, **DMA cannot access**)
 *   RAM_AXI     AXI SRAM, cacheable, DMA-capable (main bulk RAM)
 *   RAM_DMA     Last 32K of AXI SRAM, configured Non-Cacheable by MPU,
 *               use for DMA buffers to avoid manual cache maintenance
 *   RAM_SHARED  Last 16K of D2 SRAM, MPU-configured Non-Cacheable.
 *               The other 272K of D2 is CM4's private RAM (alias 0x10000000) —
 *               CM7 must NOT place anything in 0x30000000..0x30043FFF.
 *   RAM_D3      SRAM4 in D3 domain (low-power, BDMA-capable)
 *   BACKUP_SRAM Can be retained on VBAT after backup regulator setup
 * ===========================================================================
 */
MEMORY
{
  FLASH       (rx)  : ORIGIN = 0x08000000, LENGTH = 1024K
  ITCMRAM     (xrw) : ORIGIN = 0x00000000, LENGTH = 64K
  DTCMRAM     (xrw) : ORIGIN = 0x20000000, LENGTH = 128K
  RAM_AXI     (xrw) : ORIGIN = 0x24000000, LENGTH = 480K
  RAM_DMA     (xrw) : ORIGIN = 0x24078000, LENGTH = 32K
  RAM_SHARED  (xrw) : ORIGIN = 0x30044000, LENGTH = 16K
  RAM_D3      (xrw) : ORIGIN = 0x38000000, LENGTH = 64K
  BACKUP_SRAM (xrw) : ORIGIN = 0x38800000, LENGTH = 4K
}

/* Default RAM = DTCM (fastest CPU data access, no wait states) */
REGION_ALIAS("RAM", DTCMRAM);

/* Highest address of the user mode stack = end of DTCM */
_estack = ORIGIN(DTCMRAM) + LENGTH(DTCMRAM);

/* Heap / stack minimums (link-time check, runtime stack still grows from _estack) */
_Min_Heap_Size = 0x1000;      /* required amount of heap  */
_Min_Stack_Size = 0x1000; /* required amount of stack */

/* Define output sections */
SECTIONS
{
  /* Startup code at start of FLASH Bank1 */
  .isr_vector :
  {
    . = ALIGN(4);
    KEEP(*(.isr_vector))
    . = ALIGN(4);
  } >FLASH

  /* Program code */
  .text :
  {
    . = ALIGN(4);
    *(.text)
    *(.text*)
    *(.glue_7)
    *(.glue_7t)
    *(.eh_frame)

    KEEP (*(.init))
    KEEP (*(.fini))

    . = ALIGN(4);
    _etext = .;
  } >FLASH

  /* Constant data */
  .rodata :
  {
    . = ALIGN(4);
    *(.rodata)
    *(.rodata*)
    . = ALIGN(4);
  } >FLASH

  .ARM.extab (READONLY) :
  {
    . = ALIGN(4);
    *(.ARM.extab* .gnu.linkonce.armextab.*)
    . = ALIGN(4);
  } >FLASH
  .ARM (READONLY) :
  {
    . = ALIGN(4);
    __exidx_start = .;
    *(.ARM.exidx*)
    __exidx_end = .;
    . = ALIGN(4);
  } >FLASH

  .preinit_array (READONLY) :
  {
    . = ALIGN(4);
    PROVIDE_HIDDEN (__preinit_array_start = .);
    KEEP (*(.preinit_array*))
    PROVIDE_HIDDEN (__preinit_array_end = .);
    . = ALIGN(4);
  } >FLASH
  .init_array (READONLY) :
  {
    . = ALIGN(4);
    PROVIDE_HIDDEN (__init_array_start = .);
    KEEP (*(SORT(.init_array.*)))
    KEEP (*(.init_array*))
    PROVIDE_HIDDEN (__init_array_end = .);
    . = ALIGN(4);
  } >FLASH
  .fini_array (READONLY) :
  {
    . = ALIGN(4);
    PROVIDE_HIDDEN (__fini_array_start = .);
    KEEP (*(SORT(.fini_array.*)))
    KEEP (*(.fini_array*))
    PROVIDE_HIDDEN (__fini_array_end = .);
    . = ALIGN(4);
  } >FLASH

  /* Initialization data: LMA in FLASH, VMA in DTCM */
  _sidata = LOADADDR(.data);

  .data :
  {
    . = ALIGN(4);
    _sdata = .;
    *(.data)
    *(.data*)
    . = ALIGN(4);
  } >RAM AT> FLASH

  .tdata : ALIGN(4)
  {
    *(.tdata .tdata.* .gnu.linkonce.td.*)
    . = ALIGN(4);
    _edata = .;
    PROVIDE(__data_end = .);
    PROVIDE(__tdata_end = .);
  } >RAM AT> FLASH

  PROVIDE( __tdata_start = ADDR(.tdata) );
  PROVIDE( __tdata_size = __tdata_end - __tdata_start );

  PROVIDE( __data_start = ADDR(.data) );
  PROVIDE( __data_size = __data_end - __data_start );

  PROVIDE( __tdata_source = LOADADDR(.tdata) );
  PROVIDE( __tdata_source_end = LOADADDR(.tdata) + SIZEOF(.tdata) );
  PROVIDE( __tdata_source_size = __tdata_source_end - __tdata_source );

  PROVIDE( __data_source = LOADADDR(.data) );
  PROVIDE( __data_source_end = __tdata_source_end );
  PROVIDE( __data_source_size = __data_source_end - __data_source );

  /* Uninitialized data */
  .tbss (NOLOAD) : ALIGN(4)
  {
    _sbss = .;
    __bss_start__ = _sbss;
    *(.tbss .tbss.*)
    . = ALIGN(4);
    PROVIDE( __tbss_end = . );
  } >RAM

  PROVIDE( __tbss_start = ADDR(.tbss) );
  PROVIDE( __tbss_size = __tbss_end - __tbss_start );
  PROVIDE( __tbss_offset = ADDR(.tbss) - ADDR(.tdata) );

  PROVIDE( __tls_base = __tdata_start );
  PROVIDE( __tls_end = __tbss_end );
  PROVIDE( __tls_size = __tls_end - __tls_base );
  PROVIDE( __tls_align = MAX(ALIGNOF(.tdata), ALIGNOF(.tbss)) );
  PROVIDE( __tls_size_align = (__tls_size + __tls_align - 1) & ~(__tls_align - 1) );
  PROVIDE( __arm32_tls_tcb_offset = MAX(8, __tls_align) );
  PROVIDE( __arm64_tls_tcb_offset = MAX(16, __tls_align) );

  .bss (NOLOAD) : ALIGN(4)
  {
    *(.bss)
    *(.bss*)
    *(COMMON)

    . = ALIGN(4);
    _ebss = .;
    __bss_end__ = _ebss;
    PROVIDE( __bss_end = .);
  } >RAM
  PROVIDE( __non_tls_bss_start = ADDR(.bss) );

  PROVIDE( __bss_start = __tbss_start );
  PROVIDE( __bss_size = __bss_end - __bss_start );

  /* Heap + main stack sit at end of DTCM (link-time minimum check) */
  ._user_heap_stack (NOLOAD) :
  {
    . = ALIGN(8);
    PROVIDE ( end = . );
    PROVIDE ( _end = . );
    . = . + _Min_Heap_Size;
    . = . + _Min_Stack_Size;
    . = ALIGN(8);
  } >RAM

  /* ===========================================================================
   * Optional region-targeted sections
   * Use these via:
   *   __attribute__((section(".dma_buffer"))) uint8_t buf[1024];
   *   __attribute__((section(".itcm")))      void hot_func(void) { ... }
   *   __attribute__((section(".axi_ram")))   uint8_t big_array[256*1024];
   * ===========================================================================
   */

  /* Code/data placed in ITCM for zero-wait fetch */
  .itcm :
  {
    . = ALIGN(4);
    *(.itcm)
    *(.itcm*)
    . = ALIGN(4);
  } >ITCMRAM AT> FLASH
  _siitcm = LOADADDR(.itcm);
  _sitcm  = ADDR(.itcm);
  _eitcm  = ADDR(.itcm) + SIZEOF(.itcm);

  /* Bulk RAM in AXI SRAM (cacheable) */
  .axi_ram (NOLOAD) :
  {
    . = ALIGN(4);
    *(.axi_ram)
    *(.axi_ram*)
    . = ALIGN(4);
  } >RAM_AXI

  /* DMA buffer area — MPU-configured Normal Non-Cacheable
   * 32-byte aligned (one D-Cache line) to keep cache attributes clean. */
  .dma_buffer (NOLOAD) :
  {
    . = ALIGN(32);
    *(.dma_buffer)
    *(.dma_buffer*)
    . = ALIGN(32);
  } >RAM_DMA

  /* Shared RAM with CM4 (last 16K of D2 SRAM, MPU Non-Cacheable).
   * Both cores can read/write without cache maintenance. */
  .ram_shared (NOLOAD) :
  {
    . = ALIGN(4);
    *(.ram_shared)
    *(.ram_shared*)
    . = ALIGN(4);
  } >RAM_SHARED

  /* D3 low-power domain SRAM (BDMA-capable) */
  .ram_d3 (NOLOAD) :
  {
    . = ALIGN(4);
    *(.ram_d3)
    *(.ram_d3*)
    . = ALIGN(4);
  } >RAM_D3

  /* Backup SRAM (retained on VBAT) */
  .backup_sram (NOLOAD) :
  {
    . = ALIGN(4);
    *(.backup_sram)
    *(.backup_sram*)
    . = ALIGN(4);
  } >BACKUP_SRAM

  .ARM.attributes 0 : { *(.ARM.attributes) }
}
