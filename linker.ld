ENTRY(_start)

SECTIONS {
    . = 1M;

    .text : ALIGN(4k) {
        KEEP(*(.multiboot))
        *(.text)
    }

    .rodata : ALIGN(4k) {
        *(.rodata)
    }

    .data : ALIGN(4k) {
        *(.data)
    }

    .bss : ALIGN(4k) {
        *(COMMON)
        *(.bss)
    }
}
