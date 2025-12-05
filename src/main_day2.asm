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


input: resb 1000
input_capacity: equ $ - input

ranges_capacity: equ 100
ranges: resb Range_size * ranges_capacity

ranges_count: resd 1


section .text


; Checks whether given pattern is minimal (cannot be subdivided into a repeating sub-pattern)
is_pattern_minimal:
    %push
    %stacksize flat

    %arg pattern:dword
    %arg pattern_length:dword
    %arg exp_pattern_length:dword

    %assign %$localsize 0
    %local sub_pattern_length:dword
    %local exp_sub_pattern_length:dword
    %local truncator:dword
    %local head:dword
    %local tail:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    ; Loop through all repeating sub-patterns lengths up to [pattern_length]
    mov dword [sub_pattern_length], 1
    mov dword [exp_sub_pattern_length], 10
.loop:
    mov eax, [pattern_length]
    cmp [sub_pattern_length], eax
    jae .split_not_found

    ; Skip cases where [sub_pattern_length] is not divisible by [pattern_length]
    mov eax, [pattern_length]
    xor edx, edx
    div dword [sub_pattern_length]
    cmp edx, 0
    jne .continue

    ; If the sub-pattern length is a proper split, [pattern] / [exp_sub_pattern_length] should be
    ; equal to [pattern] % ([exp_pattern_length] / [exp_sub_pattern_length])

    ; First compute [truncator] = [exp_pattern_length] / [exp_sub_pattern_length]
    mov eax, [exp_pattern_length]
    xor edx, edx
    div dword [exp_sub_pattern_length]
    mov [truncator], eax

    ; Then compute [head] = [pattern] / [exp_sub_pattern_length]
    mov eax, [pattern]
    xor edx, edx
    div dword [exp_sub_pattern_length]
    mov [head], eax

    ; Then compute [tail] = [pattern] % [truncator]
    mov eax, [pattern]
    xor edx, edx
    div dword [truncator]
    mov [tail], edx

    ; We have a split if [head] = [tail]
    mov eax, [tail]
    cmp [head], eax
    je .split_found

.continue:
    ; Proceed to the next sub-pattern length
    mov eax, 10
    mul dword [exp_sub_pattern_length]
    mov [exp_sub_pattern_length], eax
    inc dword [sub_pattern_length]
    jmp .loop

.split_found:
    mov eax, 0
    jmp .done

.split_not_found:
    mov eax, 1

.done:
    add esp, %$localsize
    pop ebp
    ret 12

    %pop


main:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local pattern_length:dword
    %local pattern_range_start:dword
    %local pattern_range_end:dword
    %local pattern:dword
    %local rep_count:dword
    %local sum_low:dword
    %local sum_high:dword
    %local sum2_low:dword
    %local sum2_high:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    push esi
    push edi

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
    jge .parse_error

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

    ; If the next character is comma, continue reading more ranges
    cmp byte [esi], ','
    jne .read_end
    inc esi
    jmp .read_loop

.read_end:
    ; Check that there only a newline before end of input
    cmp byte [esi], `\n`
    jne .parse_error
    cmp byte [esi+1], 0
    jne .parse_error

    ; Initialize variables for output sums
    mov dword [sum_low], 0
    mov dword [sum_high], 0
    mov dword [sum2_low], 0
    mov dword [sum2_high], 0

    ; Loop through all possible pattern lengths of invalid IDs, maintaining the range of patterns
    ; with that length as [pattern_range_start, pattern_range_end)
    mov dword [pattern_length], 1
    mov dword [pattern_range_start], 1
    mov dword [pattern_range_end], 10
.pattern_length_loop:
    ; Loop through all patterns of length [pattern_length]
    mov eax, [pattern_range_start]
    mov [pattern], eax
.pattern_loop:
    ; Loop through all repetition counts of the pattern; edx:eax = ID obtained by repeating the
    ; pattern
    mov dword [rep_count], 1
    mov eax, [pattern]
    xor edx, edx
.rep_count_loop:
    ; Loop over ranges to check whether edx:eax is in any of them; esi = range index,
    ; edi = range pointer
    xor esi, esi
    mov edi, ranges
.range_loop:
    ; Check whether we are in the end of ranges
    cmp esi, [ranges_count]
    jge .range_checks_done

    ; Check whether edx:eax is within the range
    cmp edx, [edi+Range.start_high]
    jb .not_within_range
    jne .start_check_ok
    cmp eax, [edi+Range.start_low]
    jb .not_within_range
.start_check_ok:
    cmp edx, [edi+Range.end_high]
    jb .matching_range_found
    jne .not_within_range
    cmp eax, [edi+Range.end_low]
    jbe .matching_range_found

.not_within_range:
    ; Proceed to next range in loop
    inc esi
    add edi, Range_size
    jmp .range_loop

.matching_range_found:
    ; If repetition count is 2, add the ID edx:eax to the sum of invalid IDs with original
    ; definition
    cmp dword [rep_count], 2
    jne .rep_count_2_case_done
    add [sum_low], eax
    adc [sum_high], edx
.rep_count_2_case_done:

    ; For the new definition, we add the ID to the sum if the pattern is minimal and repetition
    ; count is at least 2
    cmp dword [rep_count], 2
    jb .range_checks_done
    push eax
    push edx
    push dword [pattern_range_end]
    push dword [pattern_length]
    push dword [pattern]
    call is_pattern_minimal
    cmp eax, 0
    pop edx
    pop eax
    je .range_checks_done
    add [sum2_low], eax
    adc [sum2_high], edx

.range_checks_done:

    ; Increase repetition count and proceed to next loop iteration unless the ID overflows
    mov ecx, edx
    mul dword [pattern_range_end]
    push eax
    push edx
    mov eax, ecx
    mul dword [pattern_range_end]
    mov ecx, eax
    pop edx
    pop eax
    jc .rep_count_loop_done
    add edx, ecx
    jc .rep_count_loop_done
    add eax, [pattern]
    adc edx, 0
    jc .rep_count_loop_done
    inc dword [rep_count]
    jmp .rep_count_loop

.rep_count_loop_done:

    ; Increment pattern, continue loop unless limit is reached
    inc dword [pattern]
    mov eax, [pattern]
    cmp eax, [pattern_range_end]
    jb .pattern_loop

    ; Increment the pattern length and the corresponding pattern range and continue loop unless
    ; limit is reached
    inc dword [pattern_length]
    mov eax, [pattern_range_end]
    mov [pattern_range_start], eax
    mov eax, [pattern_range_end]
    mov edx, 10
    mul edx
    mov [pattern_range_end], eax
    cmp dword [pattern_length], 5
    jle .pattern_length_loop

    ; Write output to stdout
    push dword [sum_high]
    push dword [sum_low]
    call write_ulong_line_to_stdout
    push dword [sum2_high]
    push dword [sum2_low]
    call write_ulong_line_to_stdout

    ; Exit status
    mov eax, 0

    pop edi
    pop esi

    add esp, %$localsize
    pop ebp
    ret

.parse_error:
    push 1
    call exit

    %pop
