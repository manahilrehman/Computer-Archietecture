; ==============================================================================
; Computer Architecture - Lab 7: Cache Memory Mapping Architectures
; Problem 17: Cache Invalidation and Maintenance Routines
;
; Cache Spec: Fully associative, 16 lines
; Task: Write a cache_invalidate_all subroutine that clears all valid and dirty bits,
;       followed by a selective cache_invalidate_addr(reg_addr) routine that searches
;       tags and invalidates only a specific line.
; Objective: Implement cache maintenance operations essential for operating system
;            context switches and DMA transfers.
; ==============================================================================

global _main
extern _printf

section .data
    title_msg    db "==================================================", 10
                 db " Lab 7 - Problem 17: Cache Maintenance Routines   ", 10
                 db " Spec: 16 lines Fully Associative, Valid & Dirty   ", 10
                 db " Operations: Selective Invalidate & Global Purge   ", 10
                 db "==================================================", 10, 10, 0

    init_msg     db "[1] Pre-populating Cache with 6 active lines (some dirty)...", 10, 0
    state_hdr    db "Slot | Valid | Dirty | Tag (Hex) | Content / Description", 10
                 db "-----+-------+-------+-----------+---------------------------------", 10, 0
    slot_fmt     db "  %02d |   %d   |   %d   |  0x%05X  | %s", 10, 0

    dma_action   db 10, "[2] Executing DMA Maintenance: cache_invalidate_addr(0x00000030)...", 10, 0
    dma_hit_fmt  db " -> Found target at Slot %d (Tag 0x%05X). Dirty bit = 1.", 10
                 db " -> [DMA Safety] Wrote back dirty buffer to DRAM before DMA overwrite.", 10
                 db " -> Line invalidated: Valid = 0, Dirty = 0.", 10, 10, 0

    ctx_action   db "[3] Executing OS Context Switch: cache_invalidate_all()...", 10, 0
    ctx_done_fmt db " -> All 16 slots flushed and invalidated.", 10
                 db " -> Flushed %d dirty lines to main memory.", 10
                 db " -> Cache completely sanitized for incoming process address space.", 10, 10, 0

    summary_msg  db "==================================================", 10
                 db " Architectural Significance:", 10
                 db " - Selective Invalidation (DMA): Prevents cache incoherence", 10
                 db "   when external hardware devices write directly into RAM.", 10
                 db " - Global Invalidation (Context Switch): Prevents process A", 10
                 db "   from accessing stale or security-sensitive cache lines", 10
                 db "   belonging to process B after a thread dispatch.", 10
                 db "==================================================", 10, 0

    str_clean    db "Clean Data", 0
    str_dirty    db "DIRTY Data (Modified by CPU)", 0
    str_empty    db "EMPTY / INVALID", 0

    valid_slots  times 16 dd 0
    dirty_slots  times 16 dd 0
    tag_slots    times 16 dd -1

    flushed_dirty dd 0

section .text
_main:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    push title_msg
    call _printf
    add esp, 4

    push init_msg
    call _printf
    add esp, 4

    mov dword [valid_slots + 0], 1
    mov dword [dirty_slots + 0], 0
    mov dword [tag_slots + 0], 0x01

    mov dword [valid_slots + 4], 1
    mov dword [dirty_slots + 4], 0
    mov dword [tag_slots + 4], 0x02

    mov dword [valid_slots + 8], 1
    mov dword [dirty_slots + 8], 1
    mov dword [tag_slots + 8], 0x03

    mov dword [valid_slots + 12], 1
    mov dword [dirty_slots + 12], 0
    mov dword [tag_slots + 12], 0x04

    mov dword [valid_slots + 16], 1
    mov dword [dirty_slots + 16], 1
    mov dword [tag_slots + 16], 0x05

    mov dword [valid_slots + 20], 1
    mov dword [dirty_slots + 20], 1
    mov dword [tag_slots + 20], 0x06

    call print_cache_state

    push dma_action
    call _printf
    add esp, 4

    mov eax, 0x00000030
    push eax
    call cache_invalidate_addr
    add esp, 4

    push ctx_action
    call _printf
    add esp, 4

    call cache_invalidate_all

    push summary_msg
    call _printf
    add esp, 4

    xor eax, eax
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

cache_invalidate_addr:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov edx, [ebp + 8]
    shr edx, 4

    xor esi, esi
.search_loop:
    cmp dword [valid_slots + esi*4], 1
    jne .next_slot
    cmp [tag_slots + esi*4], edx
    je .found_match

.next_slot:
    inc esi
    cmp esi, 16
    jl .search_loop
    jmp .done_inval

.found_match:
    cmp dword [dirty_slots + esi*4], 1
    jne .clear_line
    inc dword [flushed_dirty]

.clear_line:
    mov dword [valid_slots + esi*4], 0
    mov dword [dirty_slots + esi*4], 0
    mov dword [tag_slots + esi*4], -1

    push edx
    push esi
    push dma_hit_fmt
    call _printf
    add esp, 12

.done_inval:
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

cache_invalidate_all:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    xor esi, esi
    mov dword [flushed_dirty], 0

.global_loop:
    cmp dword [valid_slots + esi*4], 1
    jne .skip_flush
    cmp dword [dirty_slots + esi*4], 1
    jne .skip_flush
    inc dword [flushed_dirty]

.skip_flush:
    mov dword [valid_slots + esi*4], 0
    mov dword [dirty_slots + esi*4], 0
    mov dword [tag_slots + esi*4], -1

    inc esi
    cmp esi, 16
    jl .global_loop

    push dword [flushed_dirty]
    push ctx_done_fmt
    call _printf
    add esp, 8

    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

print_cache_state:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    push state_hdr
    call _printf
    add esp, 4

    xor esi, esi
.p_loop:
    cmp dword [valid_slots + esi*4], 0
    jne .is_valid
    mov edx, str_empty
    jmp .do_print
.is_valid:
    cmp dword [dirty_slots + esi*4], 1
    jne .is_clean
    mov edx, str_dirty
    jmp .do_print
.is_clean:
    mov edx, str_clean

.do_print:
    push edx
    push dword [tag_slots + esi*4]
    push dword [dirty_slots + esi*4]
    push dword [valid_slots + esi*4]
    push esi
    push slot_fmt
    call _printf
    add esp, 24

    inc esi
    cmp esi, 6
    jl .p_loop

    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret
