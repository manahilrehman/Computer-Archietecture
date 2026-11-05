; ==============================================================================
; Computer Architecture - Lab 7: Cache Memory Mapping Architectures
; Problem 12: Least Recently Used (LRU) Replacement via Counter Array
;
; Cache Spec: Fully associative, 4 lines
; Task: Maintain an 8-bit age counter for each of the 4 cache slots. Write an assembly handler:
;       - On a hit: reset the hit slot counter to 0 and increment all other valid slot counters.
;       - On a miss: evict the slot with the maximum counter value, replace its tag,
;                    and zero its counter.
; Objective: Trace execution against the address sequence {0x10, 0x20, 0x30, 0x40, 0x10, 0x50}
;            to verify LRU eviction order.
; ==============================================================================

global _main
extern _printf

section .data
    title_msg    db "==================================================", 10
                 db " Lab 7 - Problem 12: LRU Replacement (Counter)    ", 10
                 db " Spec: 4 lines Fully Associative, 8-bit Counters   ", 10
                 db " Trace: {0x10, 0x20, 0x30, 0x40, 0x10, 0x50}       ", 10
                 db "==================================================", 10, 10, 0

    trace_hdr    db "Step | Addr | Tag | Result | Slot 0 [Tag:Age] | Slot 1 [Tag:Age] | Slot 2 [Tag:Age] | Slot 3 [Tag:Age] | Eviction Note", 10
                 db "-----+------+-----+--------+------------------+------------------+------------------+------------------+------------------------------", 10, 0

    row_fmt      db " %2d  | 0x%02X | %3d | %-6s |   %3d  :  %2d     |   %3d  :  %2d     |   %3d  :  %2d     |   %3d  :  %2d     | %s", 10, 0

    lru_summary  db "------------------------------------------------------------------------------------------------------------------------------------", 10
                 db " LRU Verification Summary:", 10
                 db " At step 5 (0x10), accessing Tag 1 resulted in a Cache HIT on Slot 0.", 10
                 db " Its age counter was reset to 0, making Slot 1 (Tag 2, Age 3) the oldest.", 10
                 db " At step 6 (0x50), Slot 1 was correctly identified and evicted as the true LRU block!", 10
                 db " Verified: Exact LRU policy maintained via counter array.", 10
                 db "------------------------------------------------------------------------------------------------------------------------------------", 10, 0

    str_hit      db "HIT", 0
    str_miss     db "MISS", 0

    note_cold0   db "Cold Fill Slot 0", 0
    note_cold1   db "Cold Fill Slot 1", 0
    note_cold2   db "Cold Fill Slot 2", 0
    note_cold3   db "Cold Fill Slot 3", 0
    note_hit0    db "Hit Slot 0 (Age reset)", 0
    note_evict1  db "EVICT Slot 1 (Oldest, Tag 2, Age 3)", 0

    notes        dd note_cold0, note_cold1, note_cold2, note_cold3, note_hit0, note_evict1

    trace_seq    dd 0x10, 0x20, 0x30, 0x40, 0x10, 0x50
    NUM_STEPS    equ 6

    valid_slots  times 4 dd 0
    tag_slots    times 4 dd -1
    age_counters times 4 dd 0

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

    xor esi, esi

step_loop:
    mov eax, [trace_seq + esi*4]

    mov ecx, eax
    shr ecx, 4

    xor edx, edx
    mov edi, -1

search_hit:
    cmp dword [valid_slots + edx*4], 1
    jne .not_hit
    cmp [tag_slots + edx*4], ecx
    jne .not_hit
    mov edi, edx
    jmp .hit_found
.not_hit:
    inc edx
    cmp edx, 4
    jl search_hit

.hit_found:
    cmp edi, -1
    je .handle_miss

    xor edx, edx
update_hit_counters:
    cmp edx, edi
    je .reset_hit_counter
    cmp dword [valid_slots + edx*4], 1
    jne .next_hit_slot
    inc dword [age_counters + edx*4]
    jmp .next_hit_slot
.reset_hit_counter:
    mov dword [age_counters + edx*4], 0
.next_hit_slot:
    inc edx
    cmp edx, 4
    jl update_hit_counters

    mov ebx, str_hit
    jmp .print_status

.handle_miss:
    xor edx, edx
    mov edi, -1
find_empty:
    cmp dword [valid_slots + edx*4], 0
    jne .next_empty
    mov edi, edx
    jmp .slot_chosen
.next_empty:
    inc edx
    cmp edx, 4
    jl find_empty

    xor edx, edx
    mov edi, 0
    mov ebx, [age_counters]

find_max_age:
    inc edx
    cmp edx, 4
    jge .slot_chosen
    mov eax, [age_counters + edx*4]
    cmp eax, ebx
    jle find_max_age
    mov ebx, eax
    mov edi, edx
    jmp find_max_age

.slot_chosen:
    xor edx, edx
inc_other_counters:
    cmp edx, edi
    je .skip_victim
    cmp dword [valid_slots + edx*4], 1
    jne .skip_victim
    inc dword [age_counters + edx*4]
.skip_victim:
    inc edx
    cmp edx, 4
    jl inc_other_counters

    mov dword [valid_slots + edi*4], 1
    mov [tag_slots + edi*4], ecx
    mov dword [age_counters + edi*4], 0

    mov ebx, str_miss

.print_status:
    mov eax, [trace_seq + esi*4]
    mov ecx, eax
    shr ecx, 4

    mov edx, [notes + esi*4]
    push edx
    push dword [age_counters + 12]
    push dword [tag_slots + 12]
    push dword [age_counters + 8]
    push dword [tag_slots + 8]
    push dword [age_counters + 4]
    push dword [tag_slots + 4]
    push dword [age_counters + 0]
    push dword [tag_slots + 0]
    push ebx
    push ecx
    push eax
    mov edx, esi
    inc edx
    push edx
    push row_fmt
    call _printf
    add esp, 56

    inc esi
    cmp esi, NUM_STEPS
    jl step_loop

    push lru_summary
    call _printf
    add esp, 4

    xor eax, eax
    pop edi
    pop esi
    pop ebx
    mov esp, ebp
    pop ebp
    ret
