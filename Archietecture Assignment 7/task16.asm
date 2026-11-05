; ==============================================================================
; Computer Architecture - Lab 7: Cache Memory Mapping Architectures
; Problem 16: Optimal (Belady’s MIN) Offline Comparison
;
; Cache Spec: Fully associative, 3 lines
; Task: Given a predefined access trace stored in an array:
;       (a) Write an assembly routine simulating LRU.
;       (b) Write an assembly routine that looks ahead into future array indices
;           to evict the block unreferenced for the longest time.
; Objective: Quantify the performance gap between an online policy (LRU) and the
;            theoretical upper bound (Belady’s MIN).
; ==============================================================================

global _main
extern _printf

section .data
    title_msg    db "==================================================", 10
                 db " Lab 7 - Problem 16: Belady's MIN vs LRU Offline  ", 10
                 db " Spec: 3 lines Fully Associative                  ", 10
                 db " Trace: {1, 2, 3, 4, 1, 2, 5, 1, 2, 3, 4, 5}      ", 10
                 db "==================================================", 10, 10, 0

    table_header db "Step | Ref Block | LRU Status | LRU Cache State | MIN Status | MIN Cache State | Optimal Action", 10
                 db "-----+-----------+------------+-----------------+------------+-----------------+------------------------------", 10, 0

    row_fmt      db " %02d  |     %d     |    %-4s    |  [%d, %d, %d]   |    %-4s    |  [%d, %d, %d]   | %s", 10, 0

    summary_fmt  db "-------------------------------------------------------------------------------------------------------------", 10
                 db " Offline Optimality Gap Summary:", 10
                 db " Trace Length       : %d references", 10
                 db " LRU Hits           : %d / %d (%d%% Hit Rate)  [Online Policy]", 10
                 db " Belady's MIN Hits  : %d / %d (%d%% Hit Rate)  [Theoretical Upper Bound]", 10
                 db " Optimality Gap     : Belady's MIN achieves +%d additional hits (+%d%% boost) over LRU!", 10
                 db " Conclusion         : LRU uses backward history; MIN uses forward clairvoyance.", 10
                 db "-------------------------------------------------------------------------------------------------------------", 10, 0

    str_hit      db "HIT ", 0
    str_miss     db "MISS", 0

    act_cold     db "Cold fill", 0
    act_agree    db "Both hit / agree", 0
    act_min_win  db "MIN looks ahead: evicts farthest block!", 0

    trace_seq    dd 1, 2, 3, 4, 1, 2, 5, 1, 2, 3, 4, 5
    TRACE_LEN    equ 12

    lru_valid    times 3 dd 0
    lru_tag      times 3 dd -1
    lru_age      times 3 dd 0
    lru_hits     dd 0
    lru_misses   dd 0

    min_valid    times 3 dd 0
    min_tag      times 3 dd -1
    min_hits     dd 0
    min_misses   dd 0

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

    mov dword [lru_hits], 0
    mov dword [lru_misses], 0
    mov dword [min_hits], 0
    mov dword [min_misses], 0

    xor esi, esi

step_loop:
    mov eax, [trace_seq + esi*4]

    xor edx, edx
    mov edi, -1
.lru_search:
    cmp dword [lru_valid + edx*4], 1
    jne .lru_nxt
    cmp [lru_tag + edx*4], eax
    jne .lru_nxt
    mov edi, edx
    jmp .lru_found
.lru_nxt:
    inc edx
    cmp edx, 3
    jl .lru_search

.lru_found:
    cmp edi, -1
    je .lru_is_miss

    inc dword [lru_hits]
    xor edx, edx
.up_lru_age:
    cmp edx, edi
    je .rst_age
    cmp dword [lru_valid + edx*4], 1
    jne .nxt_up
    inc dword [lru_age + edx*4]
    jmp .nxt_up
.rst_age:
    mov dword [lru_age + edx*4], 0
.nxt_up:
    inc edx
    cmp edx, 3
    jl .up_lru_age
    mov ebx, str_hit
    jmp .do_min_step

.lru_is_miss:
    inc dword [lru_misses]
    xor edx, edx
    mov edi, -1
.find_lru_emp:
    cmp dword [lru_valid + edx*4], 0
    jne .nxt_lru_emp
    mov edi, edx
    jmp .do_lru_replace
.nxt_lru_emp:
    inc edx
    cmp edx, 3
    jl .find_lru_emp

    xor edx, edx
    mov edi, 0
    mov ecx, [lru_age]
.find_lru_old:
    inc edx
    cmp edx, 3
    jge .do_lru_replace
    cmp [lru_age + edx*4], ecx
    jle .find_lru_old
    mov ecx, [lru_age + edx*4]
    mov edi, edx
    jmp .find_lru_old

.do_lru_replace:
    xor edx, edx
.inc_lru_ages:
    cmp edx, edi
    je .skip_vic
    cmp dword [lru_valid + edx*4], 1
    jne .skip_vic
    inc dword [lru_age + edx*4]
.skip_vic:
    inc edx
    cmp edx, 3
    jl .inc_lru_ages

    mov dword [lru_valid + edi*4], 1
    mov [lru_tag + edi*4], eax
    mov dword [lru_age + edi*4], 0
    mov ebx, str_miss

.do_min_step:
    xor edx, edx
    mov edi, -1
.min_search:
    cmp dword [min_valid + edx*4], 1
    jne .min_nxt
    cmp [min_tag + edx*4], eax
    jne .min_nxt
    mov edi, edx
    jmp .min_found
.min_nxt:
    inc edx
    cmp edx, 3
    jl .min_search

.min_found:
    cmp edi, -1
    je .min_is_miss

    inc dword [min_hits]
    mov ecx, str_hit
    jmp .print_comparison

.min_is_miss:
    inc dword [min_misses]
    xor edx, edx
    mov edi, -1
.find_min_emp:
    cmp dword [min_valid + edx*4], 0
    jne .nxt_min_emp
    mov edi, edx
    jmp .do_min_install
.nxt_min_emp:
    inc edx
    cmp edx, 3
    jl .find_min_emp

    xor edx, edx
    mov edi, 0
    xor ebp, ebp

.evaluate_slots:
    mov ecx, [min_tag + edx*4]

    lea eax, [esi + 1]
.scan_future:
    cmp eax, TRACE_LEN
    jge .not_found_in_future
    cmp [trace_seq + eax*4], ecx
    je .found_at_k
    inc eax
    jmp .scan_future

.not_found_in_future:
    mov eax, 9999

.found_at_k:
    cmp eax, ebp
    jle .nxt_eval_slot
    mov ebp, eax
    mov edi, edx

.nxt_eval_slot:
    inc edx
    cmp edx, 3
    jl .evaluate_slots

.do_min_install:
    mov dword [min_valid + edi*4], 1
    mov eax, [trace_seq + esi*4]
    mov [min_tag + edi*4], eax
    mov ecx, str_miss

.print_comparison:
    mov edx, act_agree
    cmp esi, 3
    jl .set_cold
    cmp ebx, ecx
    je .have_act
    mov edx, act_min_win
    jmp .have_act
.set_cold:
    mov edx, act_cold
.have_act:

    push edx
    push dword [min_tag + 8]
    push dword [min_tag + 4]
    push dword [min_tag + 0]
    push ecx
    push dword [lru_tag + 8]
    push dword [lru_tag + 4]
    push dword [lru_tag + 0]
    push ebx
    push dword [trace_seq + esi*4]
    mov eax, esi
    inc eax
    push eax
    push row_fmt
    call _printf
    add esp, 48

    inc esi
    cmp esi, TRACE_LEN
    jl step_loop

    mov eax, [lru_hits]
    imul eax, 100
    mov ecx, TRACE_LEN
    xor edx, edx
    div ecx
    mov edi, eax

    mov eax, [min_hits]
    imul eax, 100
    xor edx, edx
    div ecx
    mov ebx, eax

    mov ecx, ebx
    sub ecx, edi

    mov edx, [min_hits]
    sub edx, [lru_hits]

    push ecx
    push edx
    push ebx
    push dword TRACE_LEN
    push dword [min_hits]
    push edi
    push dword TRACE_LEN
    push dword [lru_hits]
    push dword TRACE_LEN
    push summary_fmt
    call _printf
    add esp, 40

    xor eax, eax
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret
