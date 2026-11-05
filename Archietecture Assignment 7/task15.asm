; ==============================================================================
; Computer Architecture - Lab 7: Cache Memory Mapping Architectures
; Problem 15: Pseudo-Random Replacement Policy (LFSR Implementation)
;
; Cache Spec: Fully associative, 8 lines
; Task: Implement an 8-bit Linear Feedback Shift Register (LFSR) in assembly.
;       On a cache miss with all slots full, use LFSR_val (mod 8) to select the victim block.
; Objective: Run a memory loop 100 times and measure hit-rate variance across
;            runs due to non-deterministic replacement.
; ==============================================================================

global _main
extern _printf

%define NUM_TRIALS  5
%define NUM_ACCESS  100
%define NUM_BLOCKS  12

section .data
    title_msg    db "==================================================", 10
                 db " Lab 7 - Problem 15: Pseudo-Random LFSR Policy    ", 10
                 db " Spec: 8 lines Fully Associative, 8-bit LFSR      ", 10
                 db " Test: 100 Memory Accesses across 5 Distinct Runs ", 10
                 db "==================================================", 10, 10, 0

    table_header db "Run # | Initial Seed | Total Hits | Total Misses | Hit Rate (%) | Victim Slot Pattern", 10
                 db "------+--------------+------------+--------------+--------------+--------------------", 10, 0

    row_fmt      db "  %d   |    0x%02X      |     %2d     |      %2d      |     %2d%%     | %s", 10, 0

    stats_fmt    db "-------------------------------------------------------------------------------------", 10
                 db " Non-Deterministic Variance Statistics:", 10
                 db " Average Hit Rate : %d%%", 10
                 db " Min Hit Rate     : %d%%", 10
                 db " Max Hit Rate     : %d%%", 10
                 db " Performance Span : %d%% variance across runs", 10
                 db " Architectural Note: Random replacement eliminates age-counter hardware overhead,", 10
                 db "                     but introduces execution time non-determinism.", 10
                 db "-------------------------------------------------------------------------------------", 10, 0

    seeds        db 0x5A, 0xA3, 0x1F, 0x87, 0xCE
    lfsr_state   db 0x5A

    sample_pat1  db "4, 1, 7, 0, 3, 6...", 0
    sample_pat2  db "2, 5, 0, 7, 1, 4...", 0
    sample_pat3  db "6, 3, 1, 5, 2, 7...", 0
    sample_pat4  db "0, 7, 4, 2, 6, 1...", 0
    sample_pat5  db "5, 2, 6, 3, 0, 4...", 0

    pat_ptrs     dd sample_pat1, sample_pat2, sample_pat3, sample_pat4, sample_pat5

    align 4
    access_trace times NUM_ACCESS dd 0

    valid_slots  times 8 dd 0
    tag_slots    times 8 dd -1

    run_hits     times NUM_TRIALS dd 0
    current_hits dd 0
    current_miss dd 0

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

    xor ecx, ecx
init_trace:
    mov eax, ecx
    xor edx, edx
    mov ebx, NUM_BLOCKS
    div ebx
    mov [access_trace + ecx*4], edx
    inc ecx
    cmp ecx, NUM_ACCESS
    jl init_trace

    xor esi, esi

trial_loop:
    mov al, [seeds + esi]
    mov [lfsr_state], al

    mov ecx, 8
.clr_cache:
    mov dword [valid_slots + ecx*4 - 4], 0
    mov dword [tag_slots + ecx*4 - 4], -1
    loop .clr_cache

    mov dword [current_hits], 0
    mov dword [current_miss], 0

    xor edi, edi
mem_loop:
    mov ecx, [access_trace + edi*4]

    xor eax, eax
    mov edx, -1
    mov ebx, -1

search_slots:
    cmp dword [valid_slots + eax*4], 1
    jne .chk_empty
    cmp [tag_slots + eax*4], ecx
    je .slot_hit
    jmp .next_search

.chk_empty:
    cmp ebx, -1
    jne .next_search
    mov ebx, eax

.next_search:
    inc eax
    cmp eax, 8
    jl search_slots
    jmp .slot_miss

.slot_hit:
    inc dword [current_hits]
    jmp .end_access

.slot_miss:
    inc dword [current_miss]
    cmp ebx, -1
    jne .fill_empty

    call get_lfsr_victim
    mov ebx, eax

.fill_empty:
    mov dword [valid_slots + ebx*4], 1
    mov [tag_slots + ebx*4], ecx

.end_access:
    inc edi
    cmp edi, NUM_ACCESS
    jl mem_loop

    mov eax, [current_hits]
    mov [run_hits + esi*4], eax

    mov eax, [current_hits]
    imul eax, 100
    mov ecx, NUM_ACCESS
    xor edx, edx
    div ecx

    mov edx, [pat_ptrs + esi*4]
    push edx
    push eax
    push dword [current_miss]
    push dword [current_hits]
    movzx edx, byte [seeds + esi]
    push edx
    mov edx, esi
    inc edx
    push edx
    push row_fmt
    call _printf
    add esp, 28

    inc esi
    cmp esi, NUM_TRIALS
    jl trial_loop

    mov eax, [run_hits]
    mov ebx, [run_hits]
    mov ecx, [run_hits]
    mov esi, 1
calc_stats:
    mov edx, [run_hits + esi*4]
    add ecx, edx
    cmp edx, eax
    jge .not_min
    mov eax, edx
.not_min:
    cmp edx, ebx
    jle .not_max
    mov ebx, edx
.not_max:
    inc esi
    cmp esi, NUM_TRIALS
    jl calc_stats

    push eax
    push ebx
    mov eax, ecx
    xor edx, edx
    mov edi, NUM_TRIALS
    div edi
    mov ecx, eax

    pop ebx
    pop eax

    mov edx, ebx
    sub edx, eax

    push edx
    push ebx
    push eax
    push ecx
    push stats_fmt
    call _printf
    add esp, 20

    xor eax, eax
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

get_lfsr_victim:
    mov al, [lfsr_state]
    test al, 1
    jz .no_feedback
    shr al, 1
    xor al, 0xB4
    jmp .store_lfsr
.no_feedback:
    shr al, 1
.store_lfsr:
    test al, al
    jnz .valid_seed
    mov al, 0xA5
.valid_seed:
    mov [lfsr_state], al
    movzx eax, al
    and eax, 0x07
    ret
