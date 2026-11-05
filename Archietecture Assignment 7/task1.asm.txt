; ==============================================================================
; Computer Architecture - Lab 7: Cache Memory Mapping Architectures
; Problem 1: Single-Line Spatial Locality & Cold Misses
;
; Cache Spec: Direct-mapped, 16-byte block size (4 words per line)
; Task: Allocate a 16-word array in .data. Write an assembly loop iterating
;       through the first 4 consecutive words (array[0] to array[3]).
; Objective: Trace memory access patterns and demonstrate that accessing word 0
;            causes a cold (compulsory) miss, whereas words 1-3 result in cache
;            hits due to line fetching.
; ==============================================================================

global _main
extern _printf

section .data
    title_msg    db "==================================================", 10
                 db " Lab 7 - Problem 1: Spatial Locality & Cold Misses", 10
                 db " Cache Spec: Direct-Mapped, 16-byte line (4 words)", 10
                 db "==================================================", 10, 10, 0

    log_cold_fmt db "Access %d: Addr = 0x%08X | Word[%d] = %3d | MISS (Cold/Compulsory) -> Line [0x%08X] fetched", 10, 0
    log_hit_fmt  db "Access %d: Addr = 0x%08X | Word[%d] = %3d | HIT  (Spatial Locality) -> Line [0x%08X]", 10, 0
    summary_fmt  db 10, "--------------------------------------------------", 10
                 db " Access Summary:", 10
                 db " Total Accesses : %d", 10
                 db " Cache Hits     : %d", 10
                 db " Cache Misses   : %d (Cold: %d, Conflict/Capacity: 0)", 10
                 db " Hit Rate       : %d%%", 10
                 db "--------------------------------------------------", 10, 0

    ; 16-word array (64 bytes total)
    array        dd 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160

    cached_line  dd -1        ; -1 indicates empty line initially
    hits         dd 0
    misses       dd 0

section .text
_main:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    ; Print Header
    push title_msg
    call _printf
    add esp, 4

    ; Initialize counters
    mov dword [hits], 0
    mov dword [misses], 0
    mov dword [cached_line], -1

    xor esi, esi             ; esi = loop index i (0 to 3)

access_loop:
    ; Calculate effective address: eax = array + esi * 4
    lea eax, [array + esi*4]

    ; Calculate line tag/address: edx = address & ~15 (16-byte alignment)
    mov edx, eax
    and edx, 0xFFFFFFF0

    ; Load the actual value from array
    mov ebx, [eax]

    ; Check if line is already cached
    cmp edx, [cached_line]
    je is_cache_hit

    ; CACHE MISS (Cold Miss on first word)
    inc dword [misses]
    mov [cached_line], edx    ; Bring entire 16-byte line into cache

    ; Print Cold Miss log
    push edx                 ; Line address
    push ebx                 ; Word value
    push esi                 ; Word index
    push eax                 ; Memory address
    push esi                 ; Access number
    push log_cold_fmt
    call _printf
    add esp, 24
    jmp next_access

is_cache_hit:
    ; CACHE HIT (Spatial locality for words 1, 2, 3)
    inc dword [hits]

    ; Print Hit log
    push edx                 ; Line address
    push ebx                 ; Word value
    push esi                 ; Word index
    push eax                 ; Memory address
    push esi                 ; Access number
    push log_hit_fmt
    call _printf
    add esp, 24

next_access:
    inc esi
    cmp esi, 4               ; Access first 4 consecutive words
    jl access_loop

    ; Calculate Hit Rate = (hits * 100) / 4
    mov eax, [hits]
    imul eax, 100
    mov ecx, 4
    xor edx, edx
    div ecx                  ; eax = hit rate percentage

    ; Print Summary
    push eax                 ; Hit rate
    push dword [misses]      ; Cold misses
    push dword [misses]      ; Total misses
    push dword [hits]        ; Total hits
    push dword 4             ; Total accesses
    push summary_fmt
    call _printf
    add esp, 24

    xor eax, eax
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret
