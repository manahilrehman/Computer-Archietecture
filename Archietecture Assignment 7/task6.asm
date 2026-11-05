; ==============================================================================
; Computer Architecture - Lab 7: Cache Memory Mapping Architectures
; Problem 6: Power-of-Two Stride Degradation
;
; Cache Spec: Direct-mapped, 128 bytes total, 16-byte block size (8 sets)
; Task: Write a loop accessing a 512-byte buffer using different power-of-two
;       strides (16, 32, 64, and 128 bytes) using register-indexed addressing.
; Objective: Show how stride sizes that are multiples of the total cache capacity
;            repeatedly utilize only a single set index, degrading effective
;            capacity to 1 block.
; ==============================================================================

global _main
extern _printf

section .data
    title_msg    db "==================================================", 10
                 db " Lab 7 - Problem 6: Power-of-Two Stride Degradation", 10
                 db " Cache: 128 B Direct-Mapped (8 sets x 16 B/line)  ", 10
                 db " Buffer: 512 Bytes                                ", 10
                 db "==================================================", 10, 10, 0

    table_header db "Stride (B) | Accesses | Sets Utilized | Active Sets List   | Effective Capacity", 10
                 db "-----------+----------+---------------+--------------------+-------------------", 10, 0

    table_row    db "  %3d B    |    %2d    |   %d of 8 (%3d%%)| %-18s | %3d B (%d Block%s)", 10, 0

    degrade_msg  db 10, "==================================================", 10
                 db " Architectural Analysis:", 10
                 db " Stride = 16 B  -> Stride = Block Size    -> Uses ALL 8 sets (100%% capacity)", 10
                 db " Stride = 32 B  -> Skips every 2nd set    -> Uses 4 sets (50%% capacity)", 10
                 db " Stride = 64 B  -> Skips every 4th set    -> Uses 2 sets (25%% capacity)", 10
                 db " Stride = 128 B -> Stride = Total Cache C -> Collapses to SET 0 ONLY!", 10
                 db " Severe capacity collapse: 87.5%% of cache lines are completely wasted!", 10
                 db "==================================================", 10, 0

    strides      dd 16, 32, 64, 128
    NUM_STRIDES  equ 4

    set_str_16   db "0, 1, 2, 3, 4, 5, 6, 7", 0
    set_str_32   db "0, 2, 4, 6", 0
    set_str_64   db "0, 4", 0
    set_str_128  db "0 (COLLAPSE)", 0

    set_desc     dd set_str_16, set_str_32, set_str_64, set_str_128

    plural_s     db "s", 0
    empty_s      db "", 0

    align 16
    buffer       times 512 db 0xAA

    set_used     times 8 dd 0

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

    push table_header
    call _printf
    add esp, 4

    xor esi, esi

stride_test_loop:
    mov ebx, [strides + esi*4]

    mov ecx, 8
.clr_sets:
    mov dword [set_used + ecx*4 - 4], 0
    loop .clr_sets

    xor edx, edx
    xor edi, edi

access_buffer_loop:
    mov al, [buffer + edx]

    mov eax, edx
    shr eax, 4
    and eax, 0x07

    inc dword [set_used + eax*4]
    inc edi

    add edx, ebx
    cmp edx, 512
    jl access_buffer_loop

    xor ecx, ecx
    xor eax, eax
count_unique_sets:
    cmp dword [set_used + ecx*4], 0
    je .not_used
    inc eax
.not_used:
    inc ecx
    cmp ecx, 8
    jl count_unique_sets

    mov edx, eax
    shl edx, 4

    push eax
    imul eax, 100
    mov ecx, 8
    push edx
    xor edx, edx
    div ecx
    mov ecx, eax
    pop edx
    pop eax

    mov ebp, plural_s
    cmp eax, 1
    jne .has_plural
    mov ebp, empty_s
.has_plural:

    push ebp
    push eax
    push edx
    mov edx, [set_desc + esi*4]
    push edx
    push ecx
    push eax
    push edi
    push ebx
    push table_row
    call _printf
    add esp, 36

    inc esi
    cmp esi, NUM_STRIDES
    jl stride_test_loop

    push degrade_msg
    call _printf
    add esp, 4

    xor eax, eax
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret
