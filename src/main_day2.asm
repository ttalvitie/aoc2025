extern main

%include "exit.inc"
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

output: resb 100
output_capacity: equ $ - output

ranges_capacity: equ 100
ranges: resb Range_size * ranges_capacity

ranges_count: resd 1

section .text


main:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local half_length:dword
    %local half_id_range_start:dword
    %local half_id_range_end:dword
    %local half_id:dword
    %local sum_low:dword
    %local sum_high:dword

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

    ; Initialize variables for output sum
    mov dword [sum_low], 0
    mov dword [sum_high], 0

    ; Loop through all possible half-lengths of invalid IDs, maintaining the range of half-IDs
    ; with that length as [half_id_range_start, half_id_range_end)
    mov dword [half_length], 1
    mov dword [half_id_range_start], 1
    mov dword [half_id_range_end], 10
.half_length_loop:
    ; Loop through all half-IDs of length [half_length]
    mov eax, [half_id_range_start]
    mov [half_id], eax
.half_id_loop:
    ; Generate the full ID to edx:eax
    mov eax, [half_id_range_end]
    inc eax
    mul dword [half_id]

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
    ; Add the ID edx:eax to the sum of invalid IDs
    add [sum_low], eax
    adc [sum_high], edx

.range_checks_done:

    ; Increment half-ID, continue loop unless limit is reached
    inc dword [half_id]
    mov eax, [half_id]
    cmp eax, [half_id_range_end]
    jb .half_id_loop

    ; Increment the half-length and the corresponding half-ID range and continue loop unless limit
    ; is reached
    inc dword [half_length]
    mov eax, [half_id_range_end]
    mov [half_id_range_start], eax
    mov eax, [half_id_range_end]
    mov edx, 10
    mul edx
    mov [half_id_range_end], eax
    cmp dword [half_length], 5
    jle .half_length_loop

    ; Generate output string
    mov edi, output
    push output_capacity - 1
    push edi
    push dword [sum_high]
    push dword [sum_low]
    call ulong_to_str
    add edi, eax
    mov byte [edi], `\n`
    inc edi
    sub edi, output

    ; Write output to stdout
    push edi
    push output
    call write_all_stdout

    ; Exit status
    mov eax, 0

    pop edi
    pop esi

    add esp, %$localsize
    pop ebp
    ret

    %pop

.parse_error:
    push 1
    call exit
