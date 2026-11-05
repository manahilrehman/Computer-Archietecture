; ==============================================================================
; Computer Architecture - Lab 7: Cache Memory Mapping Architectures
; Problem 11: Tag Comparison Engine (Linear Search in Fully Associative Cache)
;
; Cache Spec: Fully associative, 8 lines, 16 bytes/line
; Task: Write an assembly routine that maintains 8 tag entries. Given an input address:
;       - Extract Tag = bits [31:4]
;       - Sequentially loop through all 8 entries to evaluate hit or miss.
; Objective: Contrast the O(1) single-cycle set-index lookup of direct-mapped
;            caches with the multi-step search required by associative software lookups.
; ==============================================================================

global _main
extern _printf

section .data
    title_msg    db "==================================================", 10
                 db " Lab 7 - Problem 11: FA Tag Comparison Engine     ", 10
                 db " Cache: Fully Associative, 8 lines (16 B/line)    ", 10
                 db " Tag Field: bits [31:4] (No set indexing)         ", 10
                 db "==================================================", 10, 10, 0

    trace_hdr    db "Address    | Tag (Hex)  | Result | Found Slot | Search Steps | Complexity", 10
                 db "-----------+------------+--------+------------+--------------+-----------", 10, 0

    hit_log_fmt  db "0x%08X | 0x%07X  | HIT    |   Slot %d   |   %d steps   | O(%d)", 10, 0
    miss_log_fmt db "0x%08X | 0x%07X  | MISS   |    None    |   8 steps    | O(N=8)", 10, 0

    summary_fmt  db "-------------------------------------------------------------------------", 10
                 db " Complexity Contrast Summary:", 10
                 db " Total Queries Tested   : %d", 10
                 db " Total Comparison Steps : %d (Average: %.1f comparisons per lookup)", 10
                 db " Direct-Mapped Overhead : Exactly 1 cycle / 1 step  [O(1)]", 10
                 db " Software FA Overhead   : Up to 8 sequential steps  [O(N)]", 10
                 db " Conclusion: Fully associative hardware requires 8 parallel comparators", 10
                 db "             to match direct-mapped single-cycle lookup speed.", 10
                 db "-------------------------------------------------------------------------", 10, 0

    test_addrs   dd 0x00001010, 0x00002020, 0x00003030, 0x00001018, \
                    0x00004040, 0x00002028, 0x00005050, 0x00009990
    NUM_QUERIES  equ 8

    valid_slots  times 8 dd 0
    tag_slots    times 8 dd -1

    total_steps  dd 0

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

    push trace_hdr
    call _printf
    add esp, 4

    mov dword [total_steps], 0

    xor esi, esi
query_loop:
    mov eax, [test_addrs + esi*4]
    push eax
    call fa_tag_search
    add esp, 4

    inc esi
    cmp esi, NUM_QUERIES
    jl query_loop

    mov eax, [total_steps]
    imul eax, 10
    mov ecx, NUM_QUERIES
    xor edx, edx
    div ecx

    push dword [total_steps]
    push dword NUM_QUERIES
    push summary_fmt
    call _printf
    add esp, 12

    xor eax, eax
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

fa_tag_search:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov edx, [ebp + 8]

    mov ecx, edx
    shr ecx, 4

    xor esi, esi
    xor ebx, ebx
    mov edi, -1

.linear_search:
    inc ebx

    cmp dword [valid_slots + esi*4], 1
    jne .check_empty

    cmp [tag_slots + esi*4], ecx
    je .found_hit
    jmp .next_slot

.check_empty:
    cmp edi, -1
    jne .next_slot
    mov edi, esi

.next_slot:
    inc esi
    cmp esi, 8
    jl .linear_search

    add [total_steps], ebx

    push ecx
    push edx
    push miss_log_fmt
    call _printf
    add esp, 12

    cmp edi, -1
    je .done_search
    mov dword [valid_slots + edi*4], 1
    mov [tag_slots + edi*4], ecx
    jmp .done_search

.found_hit:
    add [total_steps], ebx

    push ebx
    push ebx
    push esi
    push ecx
    push edx
    push hit_log_fmt
    call _printf
    add esp, 24

.done_search:
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret
