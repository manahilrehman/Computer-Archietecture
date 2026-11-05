; ==============================================================================
; Computer Architecture - Lab 7: Cache Memory Mapping Architectures
; Problem 4: Matrix Traversal: Row-Major vs. Column-Major
;
; Cache Spec: Direct-mapped, 32-byte cache line (8 words), total size = 512 bytes (16 lines)
; Task: Define a 16x16 word matrix. Write two separate subroutines:
;       (1) row-major traversal (stride = 1 word)
;       (2) column-major traversal (stride = 16 words / 64 bytes)
; Objective: Calculate theoretical hit/miss ratios for both routines and verify
;            how stride size forces multiple lines to contend for identical indices.
; ==============================================================================

global _main
extern _printf

section .data
    title_msg    db "==================================================", 10
                 db " Lab 7 - Problem 4: Row-Major vs Column-Major     ", 10
                 db " Cache: 512 B Direct-Mapped (16 lines x 32 bytes) ", 10
                 db " Matrix: 16x16 Words (1024 Bytes total)           ", 10
                 db "==================================================", 10, 10, 0

    row_fmt      db "--- [1] Row-Major Traversal (Stride = 1 word / 4 bytes) ---", 10
                 db " Total Accesses    : %d", 10
                 db " Hits              : %d (Theoretical: 224)", 10
                 db " Misses            : %d (Theoretical: 32)", 10
                 db " Hit Rate          : %d%% (Theoretical: 87.5%%)", 10
                 db " Line Utilization  : 100%% of fetched words used (8 of 8)", 10, 10, 0

    col_fmt      db "--- [2] Column-Major Traversal (Stride = 16 words / 64 bytes) ---", 10
                 db " Total Accesses    : %d", 10
                 db " Hits              : %d (Theoretical: 0)", 10
                 db " Misses            : %d (Theoretical: 256)", 10
                 db " Hit Rate          : %d%% (Theoretical: 0.0%%)", 10
                 db " Conflict Analysis : Stride of 64 B maps only to EVEN sets (0,2..14).", 10
                 db "                     Rows 0-7 and 8-15 ping-pong on identical sets!", 10, 10, 0

    compare_fmt  db "==================================================", 10
                 db " Architectural Verdict: Spatial Locality Impact   ", 10
                 db " Row-Major Miss Rate    : %d%% (Excellent spatial reuse)", 10
                 db " Column-Major Miss Rate : %d%% (Severe stride contention)", 10
                 db " Performance Factor     : Row-major is 8x more cache-friendly!", 10
                 db "==================================================", 10, 0

    align 32
    matrix       times 256 dd 1

    cache_valid  times 16 dd 0
    cache_tag    times 16 dd -1

    row_hits     dd 0
    row_misses   dd 0
    col_hits     dd 0
    col_misses   dd 0

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

    xor ecx, ecx
init_mat:
    mov [matrix + ecx*4], ecx
    inc ecx
    cmp ecx, 256
    jl init_mat

    call run_row_major
    call run_col_major

    mov eax, [row_misses]
    imul eax, 100
    mov ecx, 256
    xor edx, edx
    div ecx
    push eax

    mov ebx, [col_misses]
    imul ebx, 100
    xor edx, edx
    div ecx
    push ebx

    push compare_fmt
    call _printf
    add esp, 12

    xor eax, eax
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

run_row_major:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov ecx, 16
.reset_c:
    mov dword [cache_valid + ecx*4 - 4], 0
    mov dword [cache_tag + ecx*4 - 4], -1
    loop .reset_c

    mov dword [row_hits], 0
    mov dword [row_misses], 0

    xor esi, esi
.outer_r:
    xor edi, edi
.inner_r:
    mov eax, esi
    shl eax, 4
    add eax, edi
    lea edx, [matrix + eax*4]

    mov ebx, edx
    shr ebx, 5
    and ebx, 0x0F

    mov ecx, edx
    shr ecx, 9

    cmp dword [cache_valid + ebx*4], 1
    jne .miss_r
    cmp dword [cache_tag + ebx*4], ecx
    jne .miss_r

    inc dword [row_hits]
    jmp .next_elem_r

.miss_r:
    inc dword [row_misses]
    mov dword [cache_valid + ebx*4], 1
    mov dword [cache_tag + ebx*4], ecx

.next_elem_r:
    inc edi
    cmp edi, 16
    jl .inner_r

    inc esi
    cmp esi, 16
    jl .outer_r

    mov eax, [row_hits]
    imul eax, 100
    mov ecx, 256
    xor edx, edx
    div ecx

    push eax
    push dword [row_misses]
    push dword [row_hits]
    push dword 256
    push row_fmt
    call _printf
    add esp, 20

    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

run_col_major:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov ecx, 16
.reset_c2:
    mov dword [cache_valid + ecx*4 - 4], 0
    mov dword [cache_tag + ecx*4 - 4], -1
    loop .reset_c2

    mov dword [col_hits], 0
    mov dword [col_misses], 0

    xor edi, edi
.outer_c:
    xor esi, esi
.inner_c:
    mov eax, esi
    shl eax, 4
    add eax, edi
    lea edx, [matrix + eax*4]

    mov ebx, edx
    shr ebx, 5
    and ebx, 0x0F

    mov ecx, edx
    shr ecx, 9

    cmp dword [cache_valid + ebx*4], 1
    jne .miss_c
    cmp dword [cache_tag + ebx*4], ecx
    jne .miss_c

    inc dword [col_hits]
    jmp .next_elem_c

.miss_c:
    inc dword [col_misses]
    mov dword [cache_valid + ebx*4], 1
    mov dword [cache_tag + ebx*4], ecx

.next_elem_c:
    inc esi
    cmp esi, 16
    jl .inner_c

    inc edi
    cmp edi, 16
    jl .outer_c

    mov eax, [col_hits]
    imul eax, 100
    mov ecx, 256
    xor edx, edx
    div ecx

    push eax
    push dword [col_misses]
    push dword [col_hits]
    push dword 256
    push col_fmt
    call _printf
    add esp, 20

    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret
