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


input: resb 100000
input_capacity: equ $ - input

output: resb 100
output_capacity: equ $ - output


section .text


main:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local output_joltage:dword
    %local best_first_battery:dword
    %local best_second_battery:dword

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

    ; Initialize output joltage
    mov dword [output_joltage], 0

    ; Loop through battery banks, generating the output joltage. esi = read position
    mov esi, input
.bank_loop:
    ; Break if we are out of input
    cmp byte [esi], 0
    je .bank_loop_done

    ; Read one digit at a time, keeping track of the maximum pair
    mov dword [best_first_battery], -1
    mov dword [best_second_battery], -1
.digit_loop:
    ; Break if the line has ended
    cmp byte [esi], `\n`
    je .digit_loop_done

    ; Check that the digit is valid
    cmp byte [esi], '0'
    jl .parse_error
    cmp byte [esi], '9'
    jg .parse_error

    ; Update the maximum pair
    xor eax, eax
    mov al, [esi]
    sub eax, '0'
    cmp eax, [best_first_battery]
    jle .no_update_first
    ; Only update first if this is not the last battery
    cmp byte [esi+1], `\n`
    je .no_update_first
    mov [best_first_battery], eax
    mov dword [best_second_battery], -1
    jmp .update_done
.no_update_first:
    cmp eax, [best_second_battery]
    jle .update_done
    mov [best_second_battery], eax

.update_done:
    ; Continue loop
    inc esi
    jmp .digit_loop

.digit_loop_done:
    ; Add the joltage from this bank to the result
    mov eax, 10
    mul dword [best_first_battery]
    add eax, [best_second_battery]
    add dword [output_joltage], eax

    ; Continue the loop over banks
    inc esi
    jmp .bank_loop

.bank_loop_done:

    ; Generate output string
    mov edi, output
    push output_capacity - 1
    push edi
    push dword [output_joltage]
    call uint_to_str
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

.parse_error:
    push 1
    call exit

    %pop
