; ==============================================================================
; Computer Architecture - Lab 7: Cache Memory Mapping Architectures
; Problem 10: Loop Tiling (Blocking) for a 1D Filter
;
; Cache Spec: Direct-mapped, 256 bytes (16 lines x 16 bytes)
; Task: Implement a 3-tap moving average filter (Y[i] = (X[i-1] + X[i] + X[i+1]) / 3)
;       over an array larger than cache capacity (1024 bytes = 256 words).
;       Implement a naive loop, then implement a tiled/blocked traversal in assembly.
; Objective: Show how tiling retains array segments in the direct-mapped cache
;            across repeated access cycles.
; ==============================================================================

global _main
extern _printf

%define ARRAY_SIZE 256
%define TILE_SIZE  32
%define PASSES     2

section .data
    title_msg    db "==================================================", 10
                 db " Lab 7 - Problem 10: Loop Tiling for 1D Filter     ", 10
                 db " Cache: 256 B Direct-Mapped (16 lines x 16 B/line) ", 10
                 db " Array Size: 1024 Bytes (256 words, 4x Cache Size) ", 10
                 db " Tile Size : 128 Bytes (32 words per tile)         ", 10
                 db "==================================================", 10, 10, 0

    table_header db "Approach         | Total Accesses | Cache Hits | Cache Misses | Hit Rate", 10
                 db "-----------------+----------------+------------+--------------+---------", 10, 0

    row_fmt      db "%-16s |      %4d      |    %4d    |     %4d     |   %3d%%", 10, 0

    conclusion   db 10, "==================================================", 10
                 db " Architectural Takeaway (Tiling / Loop Blocking): ", 10
                 db " In the naive loop, the array is 4x larger than cache.", 10
                 db " Sweeping the whole array flushes early elements before", 10
                 db " pass 2 can reuse them, resulting in massive capacity misses.", 10
                 db " Tiling confines the working footprint to 128 B, ensuring", 10
                 db " data stays cache-resident across multiple filter steps!", 10
                 db "==================================================", 10, 0

    label_naive  db "Naive Filter", 0
    label_tiled  db "Tiled Filter", 0

    cache_valid  times 16 dd 0
    cache_tag    times 16 dd -1

    naive_hits   dd 0
    naive_misses dd 0
    tiled_hits   dd 0
    tiled_misses dd 0

section .bss
    X resd ARRAY_SIZE
    Y resd ARRAY_SIZE

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
.init_x:
    mov [X + ecx*4], ecx
    inc ecx
    cmp ecx, ARRAY_SIZE
    jl .init_x

    call run_naive_filter
    call run_tiled_filter

    push table_header
    call _printf
    add esp, 4

    mov eax, [naive_hits]
    imul eax, 100
    mov ecx, [naive_hits]
    add ecx, [naive_misses]
    xor edx, edx
    div ecx

    mov ebx, [naive_hits]
    add ebx, [naive_misses]

    push eax
    push dword [naive_misses]
    push dword [naive_hits]
    push ebx
    push label_naive
    push row_fmt
    call _printf
    add esp, 24

    mov eax, [tiled_hits]
    imul eax, 100
    mov ecx, [tiled_hits]
    add ecx, [tiled_misses]
    xor edx, edx
    div ecx

    mov ebx, [tiled_hits]
    add ebx, [tiled_misses]

    push eax
    push dword [tiled_misses]
    push dword [tiled_hits]
    push ebx
    push label_tiled
    push row_fmt
    call _printf
    add esp, 24

    push conclusion
    call _printf
    add esp, 4

    xor eax, eax
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

sim_access:
    push ebp
    mov ebp, esp
    push ebx

    mov edx, [ebp + 8]
    mov ebx, [ebp + 12]
    mov ecx, [ebp + 16]

    mov eax, edx
    shr eax, 4
    and eax, 0x0F

    mov edx, [ebp + 8]
    shr edx, 8

    cmp dword [cache_valid + eax*4], 1
    jne .miss
    cmp dword [cache_tag + eax*4], edx
    jne .miss

    inc dword [ebx]
    jmp .exit_sim

.miss:
    inc dword [ecx]
    mov dword [cache_valid + eax*4], 1
    mov dword [cache_tag + eax*4], edx

.exit_sim:
    pop ebx
    mov esp, ebp
    pop ebp
    ret

run_naive_filter:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov ecx, 16
.clr:
    mov dword [cache_valid + ecx*4 - 4], 0
    mov dword [cache_tag + ecx*4 - 4], -1
    loop .clr

    xor edi, edi
.pass_loop:
    mov esi, 1
.elem_loop:
    lea eax, [X + esi*4 - 4]
    push naive_misses
    push naive_hits
    push eax
    call sim_access
    add esp, 12

    lea eax, [X + esi*4]
    push naive_misses
    push naive_hits
    push eax
    call sim_access
    add esp, 12

    lea eax, [X + esi*4 + 4]
    push naive_misses
    push naive_hits
    push eax
    call sim_access
    add esp, 12

    mov eax, [X + esi*4 - 4]
    add eax, [X + esi*4]
    add eax, [X + esi*4 + 4]
    xor edx, edx
    mov ecx, 3
    div ecx
    mov [Y + esi*4], eax

    inc esi
    cmp esi, ARRAY_SIZE - 1
    jl .elem_loop

    inc edi
    cmp edi, PASSES
    jl .pass_loop

    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

run_tiled_filter:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov ecx, 16
.clr2:
    mov dword [cache_valid + ecx*4 - 4], 0
    mov dword [cache_tag + ecx*4 - 4], -1
    loop .clr2

    mov ebx, 1
.tile_loop:
    mov edx, ebx
    add edx, TILE_SIZE
    cmp edx, ARRAY_SIZE - 1
    jle .end_ok
    mov edx, ARRAY_SIZE - 1
.end_ok:

    xor edi, edi
.tile_pass:
    mov esi, ebx
.t_elem:
    lea eax, [X + esi*4 - 4]
    push tiled_misses
    push tiled_hits
    push eax
    call sim_access
    add esp, 12

    lea eax, [X + esi*4]
    push tiled_misses
    push tiled_hits
    push eax
    call sim_access
    add esp, 12

    lea eax, [X + esi*4 + 4]
    push tiled_misses
    push tiled_hits
    push eax
    call sim_access
    add esp, 12

    mov eax, [X + esi*4 - 4]
    add eax, [X + esi*4]
    add eax, [X + esi*4 + 4]
    xor edx, edx
    mov ecx, 3
    div ecx
    mov [Y + esi*4], eax

    inc esi
    cmp esi, edx
    jl .t_elem

    inc edi
    cmp edi, PASSES
    jl .tile_pass

    add ebx, TILE_SIZE
    cmp ebx, ARRAY_SIZE - 1
    jl .tile_loop

    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret
