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

    ; Write output to stdout
    push dword [fresh_count]
    call write_uint_line_to_stdout

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

.failure:
    push 2
    call exit

.ranges_overflow:
    push 3
    call exit

    %pop
