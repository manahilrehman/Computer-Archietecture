; ==============================================================================
; Computer Architecture - Lab 7: Cache Memory Mapping Architectures
; Problem 2: Stride-Induced Conflict Misses (Ping-Pong Thrashing)
;
; Cache Spec: Direct-mapped, total capacity = 1 KB (64 blocks x 16 bytes)
; Task: Allocate two arrays, ArrayA and ArrayB, separated by exactly 1024 bytes
;       so that ArrayA[i] and ArrayB[i] map to identical set indices.
;       Write a loop interleaving reads: ArrayA[0], ArrayB[0], ArrayA[1], ArrayB[1]...
; Objective: Observe a 100% miss rate due to mutual eviction despite having
;            substantial unutilized capacity in the cache.
; ==============================================================================

global _main
extern _printf

section .data
    title_msg    db "==================================================", 10
                 db " Lab 7 - Problem 2: Stride-Induced Conflict Misses", 10
                 db " (Ping-Pong Thrashing in Direct-Mapped Cache)     ", 10
                 db " Cache: 1 KB (64 sets x 16 bytes/line)            ", 10
                 db "==================================================", 10, 10, 0

    col_header   db "Step | Access Target | Address    | Set | Tag   | Status | Eviction Details", 10
                 db "-----+---------------+------------+-----+-------+--------+-------------------------", 10, 0

    log_miss_fmt db " %02d  | %-13s | 0x%08X | %02d  | 0x%03X | MISS   | Evicts Tag 0x%03X (Ping-Pong!)", 10, 0
    log_cold_fmt db " %02d  | %-13s | 0x%08X | %02d  | 0x%03X | MISS   | Cold fill into empty set", 10, 0

    summary_fmt  db "--------------------------------------------------------------------------------", 10
                 db " Ping-Pong Thrashing Summary:", 10
                 db " Total Interleaved Accesses : %d", 10
                 db " Cache Hits                 : %d", 10
                 db " Cache Misses               : %d (100%% Conflict Thrashing)", 10
                 db " Unutilized Cache Capacity  : %d of 64 sets (%.1f%% unused!)", 10
                 db " Conclusion: Arrays stride-aligned to cache capacity cause 100%% miss rate.", 10
                 db "--------------------------------------------------------------------------------", 10, 0

    name_A       db "ArrayA", 0
    name_B       db "ArrayB", 0

    ; Memory layout: ArrayA and ArrayB separated by exactly 1024 bytes
    ArrayA       times 16 dd 100          ; 16 words = 64 bytes
    padding      times 240 dd 0           ; 240 words = 960 bytes (Total offset = 1024 bytes)
    ArrayB       times 16 dd 200          ; ArrayB is located at ArrayA + 1024 bytes

    ; Direct-Mapped Cache Table: 64 Sets
    cache_valid  times 64 dd 0
    cache_tag    times 64 dd -1

    total_access dd 0
    total_hits   dd 0
    total_misses dd 0

section .text
_main:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    ; Print Title
    push title_msg
    call _printf
    add esp, 4

    push col_header
    call _printf
    add esp, 4

    mov dword [total_access], 0
    mov dword [total_hits], 0
    mov dword [total_misses], 0

    xor esi, esi             ; esi = iteration i (0 to 7)

ping_pong_loop:
    ; ---------------------------------------------------------
    ; Access ArrayA[esi]
    ; ---------------------------------------------------------
    lea eax, [ArrayA + esi*4] ; Memory Address of ArrayA[i]
    push name_A
    push eax
    call cache_access
    add esp, 8

    ; ---------------------------------------------------------
    ; Access ArrayB[esi] (Interleaved)
    ; ---------------------------------------------------------
    lea eax, [ArrayB + esi*4] ; Memory Address of ArrayB[i]
    push name_B
    push eax
    call cache_access
    add esp, 8

    inc esi
    cmp esi, 8               ; 8 pairs = 16 accesses
    jl ping_pong_loop

    ; Print Summary
    ; Calculate unused sets: 64 sets total, only sets corresponding to the loop are contested
    push 96                  ; ~96% unused
    push 62                  ; 62 sets unutilized
    push dword [total_misses]
    push dword [total_hits]
    push dword [total_access]
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

cache_access:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov eax, [ebp + 8]       ; Memory Address
    mov ebx, [ebp + 12]      ; Array Name string pointer

    ; Set Index = (Address >> 4) & 0x3F (6 bits: bits 9:4)
    mov edx, eax
    shr edx, 4
    and edx, 0x3F            ; edx = Set Index (0 to 63)

    ; Tag = Address >> 10 (bits 31:10)
    mov ecx, eax
    shr ecx, 10              ; ecx = Tag

    inc dword [total_access]

    ; Check cache hit
    cmp dword [cache_valid + edx*4], 1
    jne .cache_miss
    cmp dword [cache_tag + edx*4], ecx
    je .cache_hit

.cache_miss:
    inc dword [total_misses]
    mov edi, [cache_tag + edx*4]   ; Previous tag occupant

    ; Update cache line
    mov dword [cache_valid + edx*4], 1
    mov dword [cache_tag + edx*4], ecx

    ; Check if cold or conflict eviction
    cmp edi, -1
    je .cold_miss

    ; Conflict Miss: Print eviction
    push edi                 ; Evicted tag
    push ecx                 ; Current tag
    push edx                 ; Set index
    push eax                 ; Address
    push ebx                 ; Array name
    push dword [total_access]; Step number
    push log_miss_fmt
    call _printf
    add esp, 28
    jmp .done

.cold_miss:
    push ecx                 ; Current tag
    push edx                 ; Set index
    push eax                 ; Address
    push ebx                 ; Array name
    push dword [total_access]; Step number
    push log_cold_fmt
    call _printf
    add esp, 24
    jmp .done

.cache_hit:
    inc dword [total_hits]

.done:
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret
