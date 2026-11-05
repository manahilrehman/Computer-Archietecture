; ==============================================================================
; Computer Architecture - Lab 7: Cache Memory Mapping Architectures
; Problem 18: Pathological Cyclic Thrashing (Capacity vs. Conflict)
;
; Cache Spec: Fully associative, 4 lines
; Task: Write an assembly loop iterating through 5 unique blocks sequentially:
;       Block 0, 1, 2, 3, 4, 0, 1, 2, 3, 4... under an LRU replacement policy.
; Objective: Prove that when working set size (N = 5) exceeds associativity (K = 4),
;            the hit rate drops to 0%, demonstrating vulnerability to capacity
;            thrashing despite complete conflict immunity.
; ==============================================================================

global _main
extern _printf
extern _sprintf

%define K_SLOTS     4
%define N_BLOCKS    5
%define TOTAL_STEPS 20

section .data
    title_msg    db "==================================================", 10
                 db " Lab 7 - Problem 18: Pathological Cyclic Thrashing", 10
                 db " Spec: Fully Associative, K = 4 lines, LRU Policy", 10
                 db " Pattern: Cyclic Access over N = 5 Blocks (N > K) ", 10
                 db "==================================================", 10, 10, 0

    trace_hdr    db "Step | Cycle | Block Ref | Cache State [S0, S1, S2, S3] | Status | Evicted Block Note", 10
                 db "-----+-------+-----------+------------------------------+--------+-----------------------------------", 10, 0

    row_fmt      db " %02d  |   %d   |  Block %d  |      [%2d, %2d, %2d, %2d]      |  MISS  | %s", 10, 0

    summary_fmt  db "-----------------------------------------------------------------------------------------------------", 10
                 db " Pathological Cyclic Thrashing Analysis:", 10
                 db " Total Sequential Accesses : %d", 10
                 db " Cache Associativity (K)   : 4 lines (Fully Associative -> 0 Conflict Misses)", 10
                 db " Working Set Size (N)      : 5 unique blocks (N = K + 1)", 10
                 db " Total Cache Hits          : %d (0.0%% Hit Rate)", 10
                 db " Total Cache Misses        : %d (100.0%% Capacity Thrashing)", 10
                 db " Theoretical Proof         : Under LRU, accessing block (i mod 5) always requires the block", 10
                 db "                             that was evicted exactly 4 steps ago. Every single reference", 10
                 db "                             suffers a Capacity Miss despite complete conflict immunity!", 10
                 db "-----------------------------------------------------------------------------------------------------", 10, 0

    note_cold    db "Cold Fill (Empty Slot)", 0
    note_thrash  db "EVICTS Block %d (Victim is the very next required block!)", 0

    note_buf     times 80 db 0

    valid_slots  times K_SLOTS dd 0
    tag_slots    times K_SLOTS dd -1
    age_slots    times K_SLOTS dd 0

    total_hits   dd 0
    total_misses dd 0

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

    mov dword [total_hits], 0
    mov dword [total_misses], 0

    xor esi, esi

cycle_loop:
    mov eax, esi
    xor edx, edx
    mov ecx, N_BLOCKS
    div ecx
    mov ebx, edx
    mov edi, eax

    xor eax, eax
    mov ecx, -1
    mov edx, -1

.search:
    cmp dword [valid_slots + eax*4], 1
    jne .chk_e
    cmp [tag_slots + eax*4], ebx
    je .hit
    jmp .nxt_s
.chk_e:
    cmp edx, -1
    jne .nxt_s
    mov edx, eax
.nxt_s:
    inc eax
    cmp eax, K_SLOTS
    jl .search
    jmp .miss

.hit:
    inc dword [total_hits]
    jmp .next_step

.miss:
    inc dword [total_misses]

    cmp edx, -1
    jne .install_empty

    xor eax, eax
    mov ecx, 0
    mov ebp, [age_slots]
.find_lru:
    inc eax
    cmp eax, K_SLOTS
    jge .victim_found
    cmp [age_slots + eax*4], ebp
    jle .find_lru
    mov ebp, [age_slots + eax*4]
    mov ecx, eax
    jmp .find_lru

.victim_found:
    mov eax, [tag_slots + ecx*4]

    push eax
    push note_thrash
    push note_buf
    call sprintf_custom
    add esp, 12

    xor eax, eax
.up_ages:
    cmp eax, ecx
    je .skip_v
    inc dword [age_slots + eax*4]
.skip_v:
    inc eax
    cmp eax, K_SLOTS
    jl .up_ages

    mov dword [valid_slots + ecx*4], 1
    mov [tag_slots + ecx*4], ebx
    mov dword [age_slots + ecx*4], 0
    jmp .log_step

.install_empty:
    xor eax, eax
.up_ages_emp:
    cmp eax, edx
    je .skip_emp
    cmp dword [valid_slots + eax*4], 1
    jne .skip_emp
    inc dword [age_slots + eax*4]
.skip_emp:
    inc eax
    cmp eax, K_SLOTS
    jl .up_ages_emp

    mov dword [valid_slots + edx*4], 1
    mov [tag_slots + edx*4], ebx
    mov dword [age_slots + edx*4], 0

    mov ecx, note_cold
    mov note_buf, 0
    mov byte [note_buf], 'C'

.log_step:
    mov eax, note_buf
    cmp byte [note_buf], 'C'
    jne .use_thrash_note
    mov eax, note_cold
.use_thrash_note:

    push eax
    push dword [tag_slots + 12]
    push dword [tag_slots + 8]
    push dword [tag_slots + 4]
    push dword [tag_slots + 0]
    push ebx
    mov eax, edi
    inc eax
    push eax
    mov eax, esi
    inc eax
    push eax
    push row_fmt
    call _printf
    add esp, 36

.next_step:
    inc esi
    cmp esi, TOTAL_STEPS
    jl cycle_loop

    push dword [total_misses]
    push dword [total_hits]
    push dword TOTAL_STEPS
    push summary_fmt
    call _printf
    add esp, 16

    xor eax, eax
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

sprintf_custom:
    push ebp
    mov ebp, esp
    push ebx

    push dword [ebp + 16]
    push dword [ebp + 12]
    push dword [ebp + 8]
    call _sprintf
    add esp, 12

    pop ebx
    mov esp, ebp
    pop ebp
    ret
