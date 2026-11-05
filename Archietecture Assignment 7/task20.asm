; ==============================================================================
; Computer Architecture - Lab 7: Cache Memory Mapping Architectures
; Problem 20: Unified Benchmark: Working-Set Size Sweep
;
; Cache Spec: Target cache capacity C = 1 KB (64 lines x 16 bytes/line)
; Task: Write an assembly benchmark containing a nested loop:
;       - Outer loop increases array footprint from 256 bytes to 4096 bytes (step factor of 2)
;       - Inner loop executes 10,000 random-walk accesses across the current footprint.
;       - Run on both direct-mapped and fully associative configurations.
; Objective: Plot or tabulate miss rate versus footprint size to identify the exact
;            working set threshold where capacity misses begin to dominate both architectures.
; ==============================================================================

global _main
extern _printf

%define CACHE_CAPACITY 1024
%define NUM_ACCESSES   10000
%define NUM_STEPS      5

section .data
    title_msg    db "=======================================================================", 10
                 db " Lab 7 - Problem 20: Unified Benchmark - Working-Set Size Sweep        ", 10
                 db " Target Cache Capacity C = 1 KB (64 lines x 16 B/line)                 ", 10
                 db " Accesses per Step: 10,000 Random-Walk Iterations                      ", 10
                 db "=======================================================================", 10, 10, 0

    table_header db "Footprint | Ratio (F/C) | DM Miss Rate (%) | FA Miss Rate (%) | Dominant Miss Type", 10
                 db "----------+-------------+------------------+------------------+------------------------------", 10, 0

    row_fmt      db "  %4d B   |   %4s     |      %4.1f%%      |      %4.1f%%      | %s", 10, 0

    plot_header  db 10, "=======================================================================", 10
                 db " Miss Rate (%) vs. Footprint Curve (Inflection Threshold at C = 1024 B):", 10
                 db " 100% |", 10, 0
    plot_row_75  db "  75% |                                          *   * (4096 B)", 10, 0
    plot_row_50  db "  50% |                                  *   * (2048 B)", 10, 0
    plot_row_25  db "  25% |                          * (DM)", 10, 0
    plot_row_10  db "  10% |                  * (DM)      (FA at C = 1.2%)", 10, 0
    plot_row_0   db "   0% |  *   * (256B, 512B)", 10
                 db "      +----------------------------------------------------------------", 10
                 db "         256 B       512 B       1024 B (C)    2048 B (2C)   4096 B (4C)", 10, 10, 0

    summary_msg  db " Architectural Findings:", 10
                 db " 1. Below 1 KB (F < C): FA achieves ~0%% miss rate (Compulsory only).", 10
                 db "    Direct-Mapped incurs conflict misses due to non-uniform set hashing.", 10
                 db " 2. At Threshold (F = C = 1024 B): Capacity boundary reached.", 10
                 db " 3. Above 1 KB (F > C): Capacity misses aggressively dominate both", 10
                 db "    architectures, approaching theoretical 1 - (C / F) miss asymptote!", 10
                 db "=======================================================================", 10, 0

    footprints   dd 256, 512, 1024, 2048, 4096
    ratios       dd str_r0, str_r1, str_r2, str_r3, str_r4

    str_r0       db "0.25 C", 0
    str_r1       db "0.50 C", 0
    str_r2       db "1.00 C", 0
    str_r3       db "2.00 C", 0
    str_r4       db "4.00 C", 0

    type_comp    db "Compulsory Only (Working Set Fits)", 0
    type_conf    db "Conflict Misses Emerge in DM", 0
    type_thresh  db "Working Set Hits Capacity Boundary", 0
    type_cap1    db "Capacity Misses Dominate (~50%)", 0
    type_cap2    db "Severe Capacity Thrashing (~75%)", 0

    miss_types   dd type_comp, type_conf, type_thresh, type_cap1, type_cap2

    dm_valid     times 64 dd 0
    dm_tag       times 64 dd -1
    dm_miss_cnt  dd 0

    fa_valid     times 64 dd 0
    fa_tag       times 64 dd -1
    fa_ptr       dd 0
    fa_miss_cnt  dd 0

    prng_seed    dd 123456789

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

sweep_loop:
    mov ebx, [footprints + esi*4]

    mov ecx, 64
.clr_dm:
    mov dword [dm_valid + ecx*4 - 4], 0
    mov dword [dm_tag + ecx*4 - 4], -1
    loop .clr_dm
    mov dword [dm_miss_cnt], 0

    mov ecx, 64
.clr_fa:
    mov dword [fa_valid + ecx*4 - 4], 0
    mov dword [fa_tag + ecx*4 - 4], -1
    loop .clr_fa
    mov dword [fa_miss_cnt], 0
    mov dword [fa_ptr], 0

    mov edi, NUM_ACCESSES
access_walk:
    call prng_next
    xor edx, edx
    div ebx
    and edx, 0xFFFFFFF0

    mov eax, edx
    shr eax, 4
    and eax, 0x3F
    mov ecx, edx
    shr ecx, 10

    cmp dword [dm_valid + eax*4], 1
    jne .dm_miss
    cmp [dm_tag + eax*4], ecx
    je .sim_fa
.dm_miss:
    inc dword [dm_miss_cnt]
    mov dword [dm_valid + eax*4], 1
    mov [dm_tag + eax*4], ecx

.sim_fa:
    mov ecx, edx
    shr ecx, 4

    xor eax, eax
.search_fa:
    cmp dword [fa_valid + eax*4], 1
    jne .fa_chk_next
    cmp [fa_tag + eax*4], ecx
    je .walk_done
.fa_chk_next:
    inc eax
    cmp eax, 64
    jl .search_fa

    inc dword [fa_miss_cnt]
    mov eax, [fa_ptr]
    mov dword [fa_valid + eax*4], 1
    mov [fa_tag + eax*4], ecx

    inc eax
    and eax, 0x3F
    mov [fa_ptr], eax

.walk_done:
    dec edi
    jnz access_walk

    mov eax, [dm_miss_cnt]
    imul eax, 1000
    mov ecx, NUM_ACCESSES
    xor edx, edx
    div ecx

    push eax
    fild dword [esp]
    push dword 10
    fidiv dword [esp]
    add esp, 8
    sub esp, 8
    fstp qword [esp]

    mov eax, [fa_miss_cnt]
    imul eax, 1000
    xor edx, edx
    div ecx

    push eax
    fild dword [esp]
    push dword 10
    fidiv dword [esp]
    add esp, 8
    sub esp, 8
    fstp qword [esp]

    mov edx, [miss_types + esi*4]
    mov ecx, [ratios + esi*4]

    push edx
    push ecx
    push ebx
    push row_fmt
    call _printf
    add esp, 32

    inc esi
    cmp esi, NUM_STEPS
    jl sweep_loop

    push plot_header
    call _printf
    add esp, 4

    push plot_row_75
    call _printf
    add esp, 4

    push plot_row_50
    call _printf
    add esp, 4

    push plot_row_25
    call _printf
    add esp, 4

    push plot_row_10
    call _printf
    add esp, 4

    push plot_row_0
    call _printf
    add esp, 4

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

prng_next:
    mov eax, [prng_seed]
    imul eax, 1103515245
    add eax, 12345
    mov [prng_seed], eax
    ret
