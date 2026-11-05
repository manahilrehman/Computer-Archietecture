; ==============================================================================
; Computer Architecture - Lab 7: Cache Memory Mapping Architectures
; Problem 5: Software Direct-Mapped Cache Simulator (Bit Masking)
;
; Cache Spec: Direct-mapped, 4 lines, 16 bytes/line (total 64 bytes)
; Task: Write an assembly function cache_lookup(address) that maintains a
;       simulated tag store in memory. Use bitwise instructions to extract:
;       - Block Offset: bits [3:0]
;       - Set Index:    bits [5:4]
;       - Tag:          bits [31:6]
; Objective: Update valid bits and tags; return 1 for a cache hit and 0 for a cache miss.
; ==============================================================================

global _main
extern _printf

section .data
    title_msg    db "==================================================", 10
                 db " Lab 7 - Problem 5: Direct-Mapped Cache Simulator ", 10
                 db " Spec: 4 lines, 16 B/line (64 B Total Capacity)   ", 10
                 db " Fields: Offset[3:0], Set[5:4], Tag[31:6]         ", 10
                 db "==================================================", 10, 10, 0

    trace_header db "Address    | Tag (Hex)    | Set | Offset | Status | Action Taken", 10
                 db "-----------+--------------+-----+--------+--------+---------------------------------", 10, 0

    hit_log_fmt  db "0x%08X | 0x%07X   |  %d  |   %02d   | HIT    | Matched Tag in Set %d", 10, 0
    miss_log_fmt db "0x%08X | 0x%07X   |  %d  |   %02d   | MISS   | Installed Tag in Set %d (Old: 0x%07X)", 10, 0

    summary_fmt  db "----------------------------------------------------------------------------", 10
                 db " Simulator Summary:", 10
                 db " Total Queries  : %d", 10
                 db " Cache Hits     : %d", 10
                 db " Cache Misses   : %d", 10
                 db " Overall Hit Rate: %d%%", 10
                 db "----------------------------------------------------------------------------", 10, 0

    test_addresses dd 0x00000014, 0x00000018, 0x00000054, 0x00000020, \
                      0x00000058, 0x00000010, 0x00000030, 0x00000034
    NUM_TESTS equ 8

    valid_store  times 4 dd 0
    tag_store    times 4 dd -1

    sim_hits     dd 0
    sim_misses   dd 0

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

    push trace_header
    call _printf
    add esp, 4

    mov dword [sim_hits], 0
    mov dword [sim_misses], 0

    xor esi, esi
run_tests:
    mov eax, [test_addresses + esi*4]
    push eax
    call cache_lookup
    add esp, 4

    test eax, eax
    jz .is_miss
    inc dword [sim_hits]
    jmp .next_test

.is_miss:
    inc dword [sim_misses]

.next_test:
    inc esi
    cmp esi, NUM_TESTS
    jl run_tests

    mov eax, [sim_hits]
    imul eax, 100
    mov ecx, NUM_TESTS
    xor edx, edx
    div ecx

    push eax
    push dword [sim_misses]
    push dword [sim_hits]
    push dword NUM_TESTS
    push summary_fmt
    call _printf
    add esp, 20

    xor eax, eax
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

cache_lookup:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov edx, [ebp + 8]

    ; 1. Block Offset: bits [3:0]
    mov eax, edx
    and eax, 0x0F

    ; 2. Set Index: bits [5:4]
    mov ebx, edx
    shr ebx, 4
    and ebx, 0x03

    ; 3. Tag: bits [31:6]
    mov ecx, edx
    shr ecx, 6

    cmp dword [valid_store + ebx*4], 1
    jne .miss
    cmp dword [tag_store + ebx*4], ecx
    jne .miss

    push ebx
    push eax
    push ebx
    push ecx
    push edx
    push hit_log_fmt
    call _printf
    add esp, 24

    mov eax, 1
    jmp .exit_lookup

.miss:
    mov edi, [tag_store + ebx*4]

    mov dword [valid_store + ebx*4], 1
    mov dword [tag_store + ebx*4], ecx

    push edi
    push ebx
    push eax
    push ebx
    push ecx
    push edx
    push miss_log_fmt
    call _printf
    add esp, 28

    xor eax, eax

.exit_lookup:
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret
