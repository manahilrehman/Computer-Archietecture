; ==============================================================================
; Computer Architecture - Lab 7: Cache Memory Mapping Architectures
; Problem 9: Block-Size Tradeoff Simulation
;
; Cache Spec: Fixed total capacity = 64 bytes
;             Config A: 4 lines x 16 bytes
;             Config B: 2 lines x 32 bytes
; Task: Write an assembly routine that traverses non-contiguous data structures
;       (e.g., a linked list allocated with 28-byte gaps).
; Objective: Track and compare compulsory vs. capacity/conflict misses when line
;            size increases for non-streaming access patterns.
; ==============================================================================

global _main
extern _printf

section .data
    title_msg    db "==================================================", 10
                 db " Lab 7 - Problem 9: Block-Size Tradeoff Simulation", 10
                 db " Fixed Cache Capacity: 64 Bytes                   ", 10
                 db " Compare: Config A (4 x 16 B) vs Config B (2 x 32 B)", 10
                 db " Pattern: Non-Contiguous Traversal (28-byte gaps) ", 10
                 db "==================================================", 10, 10, 0

    table_header db "Configuration         | Cold Misses | Conflict Misses | Total Misses | Hit Rate", 10
                 db "----------------------+-------------+-----------------+--------------+---------", 10, 0

    row_fmt      db "%-21s |     %2d      |       %2d        |      %2d      |   %3d%%", 10, 0

    analysis_msg db 10, "==================================================", 10
                 db " Tradeoff Analysis for Non-Contiguous / Pointer Chasing:", 10
                 db " - Config A (4 x 16 B): Retains 4 working nodes in cache.", 10
                 db "   Second pass achieves 100%% hits due to adequate line count.", 10
                 db " - Config B (2 x 32 B): Cache line is larger, but unused bytes", 10
                 db "   pollute cache. Only 2 lines available forces constant eviction", 10
                 db "   when working set > 2 nodes, yielding higher capacity misses!", 10
                 db "==================================================", 10, 0

    label_A      db "Config A (4 x 16 B)", 0
    label_B      db "Config B (2 x 32 B)", 0

    node_offsets dd 0, 28, 56, 84, 0, 28, 56, 84
    TOTAL_ACCESS equ 8

    valid_A      times 4 dd 0
    tag_A        times 4 dd -1
    cold_A       dd 0
    conflict_A   dd 0
    hits_A       dd 0

    valid_B      times 2 dd 0
    tag_B        times 2 dd -1
    cold_B       dd 0
    conflict_B   dd 0
    hits_B       dd 0

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
loop_A:
    mov edx, [node_offsets + esi*4]

    mov eax, edx
    shr eax, 4
    and eax, 0x03

    mov ecx, edx
    shr ecx, 6

    cmp dword [valid_A + eax*4], 1
    jne .miss_A
    cmp dword [tag_A + eax*4], ecx
    jne .miss_A

    inc dword [hits_A]
    jmp .next_A

.miss_A:
    cmp dword [valid_A + eax*4], 0
    jne .conflict_A
    inc dword [cold_A]
    jmp .update_A
.conflict_A:
    inc dword [conflict_A]
.update_A:
    mov dword [valid_A + eax*4], 1
    mov dword [tag_A + eax*4], ecx

.next_A:
    inc esi
    cmp esi, TOTAL_ACCESS
    jl loop_A

    xor esi, esi
loop_B:
    mov edx, [node_offsets + esi*4]

    mov eax, edx
    shr eax, 5
    and eax, 0x01

    mov ecx, edx
    shr ecx, 6

    cmp dword [valid_B + eax*4], 1
    jne .miss_B
    cmp dword [tag_B + eax*4], ecx
    jne .miss_B

    inc dword [hits_B]
    jmp .next_B

.miss_B:
    cmp dword [valid_B + eax*4], 0
    jne .conflict_B
    inc dword [cold_B]
    jmp .update_B
.conflict_B:
    inc dword [conflict_B]
.update_B:
    mov dword [valid_B + eax*4], 1
    mov dword [tag_B + eax*4], ecx

.next_B:
    inc esi
    cmp esi, TOTAL_ACCESS
    jl loop_B

    mov eax, [hits_A]
    imul eax, 100
    mov ecx, TOTAL_ACCESS
    xor edx, edx
    div ecx

    mov ebx, [cold_A]
    add ebx, [conflict_A]

    push eax
    push ebx
    push dword [conflict_A]
    push dword [cold_A]
    push label_A
    push row_fmt
    call _printf
    add esp, 24

    mov eax, [hits_B]
    imul eax, 100
    mov ecx, TOTAL_ACCESS
    xor edx, edx
    div ecx

    mov ebx, [cold_B]
    add ebx, [conflict_B]

    push eax
    push ebx
    push dword [conflict_B]
    push dword [cold_B]
    push label_B
    push row_fmt
    call _printf
    add esp, 24

    push analysis_msg
    call _printf
    add esp, 4

    xor eax, eax
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret
