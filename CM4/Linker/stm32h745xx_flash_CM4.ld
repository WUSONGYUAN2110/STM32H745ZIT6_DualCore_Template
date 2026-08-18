/*
******************************************************************************
**
**  File        : stm32h745xx_flash_CM4.ld
**  Target      : STM32H745ZIT6 - Cortex-M4 core
**
**  Memory map  : 2MB Flash (Bank1+Bank2) / 1MB SRAM total
**                CM4 boots from Flash Bank2 @ 0x08100000
**
**  CM4 has no TCM. Default RAM is the D2 SRAM alias at 0x10000000.
**  Total D2 SRAM is 288K (SRAM1+SRAM2+SRAM3), but the LAST 16K is
**  reserved as RAM_SHARED (CM7 maps it MPU Non-Cacheable). CM4's
**  private RAM is thus 272K. See AGENTS.md.
**
**  Distribution: AS-IS, no warranty.
**
******************************************************************************
*/

ENTRY(Reset_Handler)

/* ===========================================================================
 * Memory regions (CM4 view)
 *
 *   FLASH       Bank2, CM4 code/rodata
 *   RAM         First 272K of D2 SRAM (private, default .data/.bss/heap/stack)
 *   RAM_AXI     AXI SRAM (shared with CM7 main RAM)
 *   RAM_DMA     Last 32K of AXI SRAM (Non-Cacheable on CM7 side, shared)
 *   RAM_SHARED  Last 16K of D2 SRAM (Non-Cacheable on CM7 side, shared)
 *   RAM_D3      SRAM4 D3 domain (BDMA-capable, low-power)
 *   BACKUP_SRAM Can be retained on VBAT after backup regulator setup
 * ===========================================================================
 */
MEMORY
{
  FLASH       (rx)  : ORIGIN = 0x08100000, LENGTH = 1024K
  RAM         (xrw) : ORIGIN = 0x10000000, LENGTH = 272K
  RAM_AXI     (xrw) : ORIGIN = 0x24000000, LENGTH = 480K
  RAM_DMA     (xrw) : ORIGIN = 0x24078000, LENGTH = 32K
  RAM_SHARED  (xrw) : ORIGIN = 0x10044000, LENGTH = 16K
  RAM_D3      (xrw) : ORIGIN = 0x38000000, LENGTH = 64K
  BACKUP_SRAM (xrw) : ORIGIN = 0x38800000, LENGTH = 4K
}

/* Highest address of the user mode stack = end of RAM */
_estack = ORIGIN(RAM) + LENGTH(RAM);

_Min_Heap_Size = 0x1000;      /* required amount of heap  */
_Min_Stack_Size = 0x1000; /* required amount of stack */

SECTIONS
{
  .isr_vector :
  {
    . = ALIGN(4);
    KEEP(*(.isr_vector))
    . = ALIGN(4);
  } >FLASH

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

  .rodata :
  {
    . = ALIGN(4);
    *(.rodata)
    *(.rodata*)
    . = ALIGN(4);
  } >FLASH

  .ARM.extab (READONLY) :
  {
    *(.ARM.extab* .gnu.linkonce.armextab.*)
  } >FLASH
  .ARM (READONLY) :
  {
    __exidx_start = .;
    *(.ARM.exidx*)
    __exidx_end = .;
  } >FLASH

  .preinit_array (READONLY) :
  {
    PROVIDE_HIDDEN (__preinit_array_start = .);
    KEEP (*(.preinit_array*))
    PROVIDE_HIDDEN (__preinit_array_end = .);
  } >FLASH
  .init_array (READONLY) :
  {
    PROVIDE_HIDDEN (__init_array_start = .);
    KEEP (*(SORT(.init_array.*)))
    KEEP (*(.init_array*))
    PROVIDE_HIDDEN (__init_array_end = .);
  } >FLASH
  .fini_array (READONLY) :
  {
    PROVIDE_HIDDEN (__fini_array_start = .);
    KEEP (*(SORT(.fini_array.*)))
    KEEP (*(.fini_array*))
    PROVIDE_HIDDEN (__fini_array_end = .);
  } >FLASH

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
   * Optional region-targeted sections (see AGENTS.md)
   * ===========================================================================
   */

  /* AXI SRAM shared with CM7 */
  .axi_ram (NOLOAD) :
  {
    . = ALIGN(4);
    *(.axi_ram)
    *(.axi_ram*)
    . = ALIGN(4);
  } >RAM_AXI

  /* DMA buffer shared region (Non-Cacheable on CM7) */
  .dma_buffer (NOLOAD) :
  {
    . = ALIGN(32);
    *(.dma_buffer)
    *(.dma_buffer*)
    . = ALIGN(32);
  } >RAM_DMA

  /* Shared with CM7 (last 16K of D2 SRAM, MPU Non-Cacheable on CM7 side) */
  .ram_shared (NOLOAD) :
  {
    . = ALIGN(4);
    *(.ram_shared)
    *(.ram_shared*)
    . = ALIGN(4);
  } >RAM_SHARED

  /* D3 low-power SRAM */
  .ram_d3 (NOLOAD) :
  {
    . = ALIGN(4);
    *(.ram_d3)
    *(.ram_d3*)
    . = ALIGN(4);
  } >RAM_D3

  /* Backup SRAM */
  .backup_sram (NOLOAD) :
  {
    . = ALIGN(4);
    *(.backup_sram)
    *(.backup_sram*)
    . = ALIGN(4);
  } >BACKUP_SRAM

  .ARM.attributes 0 : { *(.ARM.attributes) }
}
