extern main

%include "exit.inc"
%include "io.inc"
%include "math.inc"
%include "number_str.inc"
%include "raw_io.inc"


struc Range
    .start_low resd 1
    .start_high resd 1
    .end_low resd 1
    .end_high resd 1
endstruc


section .bss


input: resb 100000
input_capacity: equ $ - input

ranges_capacity: equ 1000
ranges: resb Range_size * ranges_capacity

ranges_count: resd 1


section .text


main:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local fresh_count:dword
    %local all_fresh_count_low:dword
    %local all_fresh_count_high:dword
    %local current_low:dword
    %local current_high:dword
    %local next_low:dword
    %local next_high:dword
    %local next_active_diff:dword
    %local active_count:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    push esi
    push edi
    push ebx

    ; Read input
    push input_capacity - 1
    push input
    call read_all_stdin

    ; Add 0-byte to end of input
    mov byte [input+eax], 0

    ; Read ranges from input in loop; esi = input position, edi = range pointer
    mov dword [ranges_count], 0
    mov esi, input
    mov edi, ranges
.read_loop:
    ; Check that we don't overflow the ranges array
    cmp dword [ranges_count], ranges_capacity
    jge .ranges_overflow

    ; Read the range
    push esi
    call parse_ulong
    mov [edi+Range.start_low], eax
    mov [edi+Range.start_high], edx
    mov esi, ecx
    cmp byte [esi], '-'
    jne .parse_error
    inc esi
    push esi
    call parse_ulong
    mov [edi+Range.end_low], eax
    mov [edi+Range.end_high], edx
    mov esi, ecx

    ; Increment range count and output position
    inc dword [ranges_count]
    add edi, Range_size

    ; The range must be followed by a newline
    cmp byte [esi], `\n`
    jne .parse_error
    inc esi

    ; If the newline is followed by another newline, we have reached the end of ranges.
    ; Otherwise, continue reading ranges.
    cmp byte [esi], `\n`
    jne .read_loop

    ; Initialize the result variable
    mov dword [fresh_count], 0

    ; Proceed to reading the IDs
    inc esi
.id_loop:
    ; Exit the loop if we have reached the end of input
    cmp byte [esi], 0
    je .id_loop_done

    ; Read the ID to edx:eax
    push esi
    call parse_ulong
    mov esi, ecx

    ; Determine whether the ingredient is fresh by looping through the ranges and seeing if it is
    ; contained in one of them; edi = range pointer, ecx = range index
    mov edi, ranges
    xor ecx, ecx
.range_loop:
    cmp ecx, [ranges_count]
    ja .failure
    je .range_loop_done

    ; Check whether the ID edx:eax is in the range [edi]
    cmp edx, [edi+Range.start_high]
    jb .range_loop_continue
    ja .start_ok
    cmp eax, [edi+Range.start_low]
    jb .range_loop_continue
.start_ok:
    cmp edx, [edi+Range.end_high]
    ja .range_loop_continue
    jb .inside_range
    cmp eax, [edi+Range.end_low]
    ja .range_loop_continue
.inside_range:
    ; The ID is within the range, increase fresh count and break out of the loop over ranges
    inc dword [fresh_count]
    jmp .range_loop_done

.range_loop_continue:

    ; Continue to the next range in the loop
    add edi, Range_size
    inc ecx
    jmp .range_loop
.range_loop_done:

    ; The ID must be followed by a newline
    cmp byte [esi], `\n`
    jne .parse_error
    inc esi

    ; Continue the loop to the next ID
    jmp .id_loop

.id_loop_done:

    ; Start computing the number of all IDs considered fresh by the ranges by going through all the
    ; events in endpoints in order and keeping track on how many ranges we are inside.
    mov dword [all_fresh_count_low], 0
    mov dword [all_fresh_count_high], 0
    mov dword [current_low], 0
    mov dword [current_high], -1
    mov dword [active_count], 0
.event_loop:
    ; Find the next event in a brute-force way by looping over all ranges;
    ; edi = range pointer, ecx = range index
    mov dword [next_low], 0
    mov dword [next_high], -1
    mov edi, ranges
    xor ecx, ecx
.event_range_loop:
    cmp ecx, [ranges_count]
    ja .failure
    je .event_range_loop_done

    ; Routine for considering the event at edx:eax with active diff in ebx
    jmp .after_consider_event
.consider_event:
    ; Only consider events after the current event
    cmp edx, [current_high]
    jg .event_after_current
    jl .consider_event_break
    cmp eax, [current_low]
    jbe .consider_event_break
.event_after_current:

    ; If the event is before [next_high]:[next_low], make it the new next event
    cmp edx, [next_high]
    jb .event_before_next
    ja .next_update_done
    cmp eax, [next_low]
    jae .next_update_done
.event_before_next:
    mov [next_low], eax
    mov [next_high], edx
    mov dword [next_active_diff], 0
.next_update_done:

    ; If event is at [next_high]:[next_low], add ebx to its diff
    cmp eax, [next_low]
    jne .consider_event_break
    cmp edx, [next_high]
    jne .consider_event_break
    add [next_active_diff], ebx

.consider_event_break:
    ret
.after_consider_event:

    ; Consider the events for the endpoints of the range
    mov eax, [edi+Range.start_low]
    mov edx, [edi+Range.start_high]
    mov ebx, 1
    call .consider_event
    mov eax, [edi+Range.end_low]
    mov edx, [edi+Range.end_high]
    add eax, 1
    adc edx, 0
    mov ebx, -1
    call .consider_event

    ; Continue to the next range in the loop
    add edi, Range_size
    inc ecx
    jmp .event_range_loop
.event_range_loop_done:

    ; If no next event was found, exit the loop over events
    cmp dword [next_high], -1
    je .event_loop_done

    ; If there are ranges active, add the distance between the events to the result
    cmp dword [active_count], 0
    jl .failure
    je .distance_add_done
    mov eax, [next_low]
    mov edx, [next_high]
    sub eax, [current_low]
    sbb edx, [current_high]
    add [all_fresh_count_low], eax
    adc [all_fresh_count_high], edx
.distance_add_done:

    ; Update the number of active ranges
    mov eax, [next_active_diff]
    add [active_count], eax

    ; Move to the new event
    mov eax, [next_low]
    mov [current_low], eax
    mov eax, [next_high]
    mov [current_high], eax

    ; Continue the loop to the next event
    jmp .event_loop
.event_loop_done:

    ; Write output to stdout
    push dword [fresh_count]
    call write_uint_line_to_stdout
    push dword [all_fresh_count_high]
    push dword [all_fresh_count_low]
    call write_ulong_line_to_stdout

    ; Exit status
    mov eax, 0

    pop ebx
    pop edi
    pop esi

    add esp, %$localsize
    pop ebp
    ret

.parse_error:
    push 1
    call exit

.failure:
    push 2
    call exit

.ranges_overflow:
    push 3
    call exit

    %pop
