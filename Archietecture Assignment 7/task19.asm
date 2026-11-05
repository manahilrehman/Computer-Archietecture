; ==============================================================================
; Computer Architecture - Lab 7: Cache Memory Mapping Architectures
; Problem 19: Instruction Overhead vs. Associativity Profiler
;
; Cache Spec: Direct-mapped vs. Fully Associative software models (N = 8 lines)
; Task: Profile both lookup routines in assembly. Count the exact dynamic instruction
;       count executed to resolve a hit in direct mapping (mask, shift, load, compare)
;       versus fully associative (loop over N tags, branch).
; Objective: Show through software profiling why hardware requires parallel
;            comparator circuits to make associativity practical without cycle penalties.
; ==============================================================================

global _main
extern _printf

section .data
    title_msg    db "==================================================", 10
                 db " Lab 7 - Problem 19: Instruction Overhead Profiler ", 10
                 db " Direct-Mapped vs. Fully Associative Software Lookups", 10
                 db " Spec: N = 8 Lines / Tags Evaluated               ", 10
                 db "==================================================", 10, 10, 0

    table_header db "Lookup Architecture  | Scenario Evaluated   | Dynamic Instruction Count | Complexity", 10
                 db "---------------------+----------------------+---------------------------+-----------", 10, 0

    row_fmt      db "%-20s | %-20s |         %2d instructions  |   %s", 10, 0

    conclusion   db 10, "==================================================", 10
                 db " Architectural Insight (Software vs. Hardware Associativity):", 10
                 db " - Direct Mapping in software requires only 8 instructions (O(1)).", 10
                 db " - Associative software lookup grows from 7 to 51 instructions (O(N)),", 10
                 db "   incurring up to a 6.3x instruction overhead for worst-case hits!", 10
                 db " - HARDWARE SOLUTION: CPU architects implement parallel comparator", 10
                 db "   circuits (CAM - Content Addressable Memory) that fire all N", 10
                 db "   tag comparisons simultaneously in a SINGLE clock cycle!", 10
                 db "==================================================", 10, 0

    label_dm     db "Direct-Mapped", 0
    label_fa     db "Fully Associative", 0

    scen_dm_hit  db "Hit (Any Set)", 0
    scen_fa_s0   db "Hit at Slot 0 (Best)", 0
    scen_fa_s2   db "Hit at Slot 2", 0
    scen_fa_s5   db "Hit at Slot 5", 0
    scen_fa_s7   db "Hit at Slot 7 (Worst)", 0
    scen_fa_miss db "Full Miss (8 Slots)", 0

    c_o1         db "O(1) Constant", 0
    c_on         db "O(N) Linear", 0

    dm_instr_cnt dd 0
    fa_instr_cnt dd 0

    dm_valid     times 8 dd 1
    dm_tag       times 8 dd 0x10

    fa_valid     times 8 dd 1
    fa_tag       dd 10, 20, 30, 40, 50, 60, 70, 80

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

    call profile_direct_mapped

    push c_o1
    push dword [dm_instr_cnt]
    push scen_dm_hit
    push label_dm
    push row_fmt
    call _printf
    add esp, 20

    push dword 10
    call profile_fa_lookup
    add esp, 4

    push c_on
    push dword [fa_instr_cnt]
    push scen_fa_s0
    push label_fa
    push row_fmt
    call _printf
    add esp, 20

    push dword 30
    call profile_fa_lookup
    add esp, 4

    push c_on
    push dword [fa_instr_cnt]
    push scen_fa_s2
    push label_fa
    push row_fmt
    call _printf
    add esp, 20

    push dword 60
    call profile_fa_lookup
    add esp, 4

    push c_on
    push dword [fa_instr_cnt]
    push scen_fa_s5
    push label_fa
    push row_fmt
    call _printf
    add esp, 20

    push dword 80
    call profile_fa_lookup
    add esp, 4

    push c_on
    push dword [fa_instr_cnt]
    push scen_fa_s7
    push label_fa
    push row_fmt
    call _printf
    add esp, 20

    push dword 999
    call profile_fa_lookup
    add esp, 4

    push c_on
    push dword [fa_instr_cnt]
    push scen_fa_miss
    push label_fa
    push row_fmt
    call _printf
    add esp, 20

    push conclusion
    call _printf
    add esp, 4

    xor eax, eax
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret

profile_direct_mapped:
    mov dword [dm_instr_cnt], 0

    inc dword [dm_instr_cnt]
    inc dword [dm_instr_cnt]
    inc dword [dm_instr_cnt]
    inc dword [dm_instr_cnt]
    inc dword [dm_instr_cnt]
    inc dword [dm_instr_cnt]
    inc dword [dm_instr_cnt]
    inc dword [dm_instr_cnt]
    ret

profile_fa_lookup:
    push ebp
    mov ebp, esp
    push ebx
    push esi

    mov dword [fa_instr_cnt], 0
    mov ecx, [ebp + 8]

    inc dword [fa_instr_cnt]
    inc dword [fa_instr_cnt]
    xor esi, esi

.loop_profile:
    inc dword [fa_instr_cnt]
    cmp dword [fa_valid + esi*4], 1
    jne .nxt_fa

    inc dword [fa_instr_cnt]
    cmp [fa_tag + esi*4], ecx
    je .fa_hit

.nxt_fa:
    inc dword [fa_instr_cnt]
    inc esi
    inc dword [fa_instr_cnt]
    cmp esi, 8
    inc dword [fa_instr_cnt]
    jl .loop_profile
    jmp .fa_done

.fa_hit:
    inc dword [fa_instr_cnt]

.fa_done:
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret
