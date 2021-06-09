ENTRY(_start)

SECTIONS {
    . = 1M;

    .text : ALIGN(4k) {
        KEEP(*(.multiboot))
        *(.text)
    }

    .rodata : ALIGN(4k) {
        *(.rodata)

        __debug_info_start = .;
        KEEP(*(.debug_info))
        __debug_info_end = .;
        __debug_abbrev_start = .;
        KEEP(*(.debug_abbrev))
        __debug_abbrev_end = .;
        __debug_str_start = .;
        KEEP(*(.debug_str))
        __debug_str_end = .;
        __debug_line_start = .;
        KEEP(*(.debug_line))
        __debug_line_end = .;
        __debug_ranges_start = .;
        KEEP(*(.debug_ranges))
        __debug_ranges_end = .;
    }

    .data : ALIGN(4k) {
        *(.data)
    }

    .bss : ALIGN(4k) {
        *(COMMON)
        *(.bss)
    }
}
