; ==============================================================================
; Computer Architecture - Lab 7: Cache Memory Mapping Architectures
; Problem 8: Instruction Cache Thrashing via Branch Bouncing
;
; Cache Spec: Direct-mapped L1 Instruction Cache (512 bytes, 16 bytes/line = 32 sets)
; Task: Write two small routines, FuncA and FuncB. Position them in the .text segment
;       (using .align or address offsets) such that their entry points map to the
;       exact same cache set. Write a loop alternating calls between them.
; Objective: Measure instruction cache miss rate spikes caused by mutual
;            instruction-line eviction.
; ==============================================================================

global _main
extern _printf

section .data
    title_msg    db "==================================================", 10
                 db " Lab 7 - Problem 8: Instruction Cache Thrashing   ", 10
                 db " (Branch Bouncing on Direct-Mapped L1 I-Cache)    ", 10
                 db " Spec: 512 B L1 I-Cache (32 sets x 16 B/line)     ", 10
                 db "==================================================", 10, 10, 0

    trace_hdr    db "Call # | Executing | Routine PC | I-Set | Tag   | Status | Instruction Cache Action", 10
                 db "-------+-----------+------------+-------+-------+--------+-----------------------------------", 10, 0

    log_miss_fmt db "  %02d   | %-9s | 0x%08X |  %02d   | 0x%03X | MISS   | Line Eviction (Branch Bounce Thrash!)", 10, 0
    log_cold_fmt db "  %02d   | %-9s | 0x%08X |  %02d   | 0x%03X | MISS   | Cold fetch into Set %02d", 10, 0

    summary_fmt  db "-------------------------------------------------------------------------------------", 10
                 db " Branch Bouncing (I-Cache Thrashing) Results:", 10
                 db " Total Routine Calls       : %d", 10
                 db " I-Cache Hits              : %d (0.0%%)", 10
                 db " I-Cache Misses            : %d (100.0%% Thrashing Spike)", 10
                 db " Root Cause                : FuncA and FuncB entry points map to identical Set %d.", 10
                 db " Architectural Solution    : Re-align routine entry points or use 2-way associative I-cache.", 10
                 db "-------------------------------------------------------------------------------------", 10, 0

    name_fa      db "FuncA", 0
    name_fb      db "FuncB", 0

    icache_valid times 32 dd 0
    icache_tag   times 32 dd -1

    icall_count  dd 0
    ihits        dd 0
    imisses      dd 0

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

    mov dword [icall_count], 0
    mov dword [ihits], 0
    mov dword [imisses], 0

    xor esi, esi
bounce_loop:
    push name_fa
    push FuncA
    call simulate_icache_fetch
    add esp, 8
    call FuncA

    push name_fb
    push FuncB
    call simulate_icache_fetch
    add esp, 8
    call FuncB

    inc esi
    cmp esi, 8
    jl bounce_loop

    mov eax, FuncA
    shr eax, 4
    and eax, 0x1F

    push eax
    push dword [imisses]
    push dword [ihits]
    push dword [icall_count]
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

simulate_icache_fetch:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov eax, [ebp + 8]
    mov ebx, [ebp + 12]

    inc dword [icall_count]

    mov edx, eax
    shr edx, 4
    and edx, 0x1F

    mov ecx, eax
    shr ecx, 9

    cmp dword [icache_valid + edx*4], 1
    jne .imiss
    cmp dword [icache_tag + edx*4], ecx
    je .ihit

.imiss:
    inc dword [imisses]
    mov edi, [icache_tag + edx*4]

    mov dword [icache_valid + edx*4], 1
    mov dword [icache_tag + edx*4], ecx

    cmp edi, -1
    je .icold

    push ecx
    push edx
    push eax
    push ebx
    push dword [icall_count]
    push log_miss_fmt
    call _printf
    add esp, 24
    jmp .done_fetch

.icold:
    push edx
    push ecx
    push edx
    push eax
    push ebx
    push dword [icall_count]
    push log_cold_fmt
    call _printf
    add esp, 28
    jmp .done_fetch

.ihit:
    inc dword [ihits]

.done_fetch:
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

align 512
FuncA:
    mov eax, 10
    add eax, 20
    ret

align 512
FuncB:
    mov eax, 30
    sub eax, 15
    ret
