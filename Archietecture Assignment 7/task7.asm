; ==============================================================================
; Computer Architecture - Lab 7: Cache Memory Mapping Architectures
; Problem 7: Write-Through vs. Write-Back Flag Tracking
;
; Cache Spec: Direct-mapped, 8 blocks (16 bytes per block)
; Task: In a software-modeled cache structure, maintain a dirty bit array alongside
;       tag and valid bits. Implement store_word(addr, val):
;       - On a miss, evict the current occupant.
;       - If the evicted line is dirty, invoke a simulated mem_writeback() routine
;         before fetching new data.
; Objective: Count memory write bus transactions under burst write access patterns.
; ==============================================================================

global _main
extern _printf

section .data
    title_msg    db "==================================================", 10
                 db " Lab 7 - Problem 7: Write-Through vs Write-Back   ", 10
                 db " Cache: Direct-Mapped, 8 Blocks                   ", 10
                 db " Tracking: Valid bit, Tag, and Dirty bit          ", 10
                 db "==================================================", 10, 10, 0

    trace_hdr    db "Op # | Address    | Set | Tag   | Action | Cache Status | WB Bus Tx | WT Bus Tx", 10
                 db "-----+------------+-----+-------+--------+--------------+-----------+----------", 10, 0

    hit_log_fmt  db " %02d  | 0x%08X |  %d  | 0x%03X | WRITE  | HIT (Dirty)  |     %2d    |    %2d", 10, 0
    cold_log_fmt db " %02d  | 0x%08X |  %d  | 0x%03X | WRITE  | MISS (Cold)  |     %2d    |    %2d", 10, 0
    wb_evict_fmt db " %02d  | 0x%08X |  %d  | 0x%03X | EVICT  | DIRTY FLUSH  |    [%2d]   |    %2d", 10, 0

    summary_fmt  db "-------------------------------------------------------------------------------", 10
                 db " Memory Bus Write Transactions Summary:", 10
                 db " Total Store Operations   : %d writes", 10
                 db " Write-Through Bus Writes : %d transactions (100%% bus occupancy)", 10
                 db " Write-Back Bus Writes    : %d transactions (Dirty writebacks only)", 10
                 db " Bus Traffic Reduction    : %d%% traffic eliminated via Dirty-bit caching!", 10
                 db "-------------------------------------------------------------------------------", 10, 0

    burst_addrs  dd 0x00000100, 0x00000104, 0x00000108, 0x0000010C, \
                    0x00000100, 0x00000104, 0x00000200, 0x00000204, \
                    0x00000208, 0x00000100, 0x00000300, 0x00000304
    burst_vals   dd 11, 22, 33, 44, 55, 66, 77, 88, 99, 101, 202, 303
    NUM_STORES   equ 12

    valid_array  times 8 dd 0
    tag_array    times 8 dd -1
    dirty_array  times 8 dd 0

    wt_bus_count dd 0
    wb_bus_count dd 0
    op_counter   dd 0

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

    mov dword [wt_bus_count], 0
    mov dword [wb_bus_count], 0
    mov dword [op_counter], 0

    xor esi, esi

store_loop:
    mov eax, [burst_addrs + esi*4]
    mov ebx, [burst_vals + esi*4]

    push ebx
    push eax
    call store_word
    add esp, 8

    inc esi
    cmp esi, NUM_STORES
    jl store_loop

    mov eax, [wt_bus_count]
    sub eax, [wb_bus_count]
    imul eax, 100
    mov ecx, [wt_bus_count]
    xor edx, edx
    div ecx

    push eax
    push dword [wb_bus_count]
    push dword [wt_bus_count]
    push dword NUM_STORES
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

store_word:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi

    mov edx, [ebp + 8]
    mov ebx, [ebp + 12]

    inc dword [op_counter]
    inc dword [wt_bus_count]

    mov eax, edx
    shr eax, 4
    and eax, 0x07

    mov ecx, edx
    shr ecx, 7

    cmp dword [valid_array + eax*4], 1
    jne .miss
    cmp dword [tag_array + eax*4], ecx
    jne .miss

    mov dword [dirty_array + eax*4], 1

    push dword [wt_bus_count]
    push dword [wb_bus_count]
    push ecx
    push eax
    push edx
    push dword [op_counter]
    push hit_log_fmt
    call _printf
    add esp, 28
    jmp .done_store

.miss:
    cmp dword [valid_array + eax*4], 1
    jne .install_new
    cmp dword [dirty_array + eax*4], 1
    jne .install_new

    push edx
    push eax
    push ecx
    call mem_writeback
    pop ecx
    pop eax
    pop edx

    push dword [wt_bus_count]
    push dword [wb_bus_count]
    push ecx
    push eax
    push edx
    push dword [op_counter]
    push wb_evict_fmt
    call _printf
    add esp, 28

.install_new:
    mov dword [valid_array + eax*4], 1
    mov dword [tag_array + eax*4], ecx
    mov dword [dirty_array + eax*4], 1

    push dword [wt_bus_count]
    push dword [wb_bus_count]
    push ecx
    push eax
    push edx
    push dword [op_counter]
    push cold_log_fmt
    call _printf
    add esp, 28

.done_store:
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

mem_writeback:
    inc dword [wb_bus_count]
    ret
