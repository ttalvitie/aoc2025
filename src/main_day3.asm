extern main

%include "exit.inc"
%include "io.inc"
%include "math.inc"
%include "number_str.inc"
%include "raw_io.inc"


section .bss


input: resb 100000
input_capacity: equ $ - input


section .text


; Optimize the batteries turned on in a single bank
; (bank start pointer, bank length, number of batteries to turn on) -> (result low bits, result high bits)
optimize_bank:
    %push
    %stacksize flat

    %arg bank:dword
    %arg bank_length:dword
    %arg set_size:dword

    %assign %$localsize 0
    %local selected_count:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    ; Check argument validity
    mov eax, [bank_length]
    cmp eax, 0
    jle .failure
    cmp [set_size], eax
    ja .failure
    cmp dword [set_size], 18
    ja .failure

    ; Allocate stack space for the array of selected digits and terminating 0-byte, initialize its
    ; length to 0
    dec esp
    mov byte [esp], 0
    sub esp, [set_size]
    mov dword [selected_count], 0

    ; Iterate through the digits, optimizing the selection. [bank] points to the next digit, and
    ; [bank_length] is the number of remaining digits
.digit_loop:
    cmp dword [bank_length], 0
    je .digit_loop_done

    ; Find the position to place the next digit in the array of selected digits. We want to place
    ; it after the last digit that is equal or larger to it, erasing all the digits after it.
    ; However, we only consider the suffix of length at most [bank_length] to ensure that the
    ; array of selected digits gets filled. Set ecx to the index of the first possible position.
    mov ecx, [set_size]
    sub ecx, [bank_length]
    cmp ecx, [selected_count]
    jg .failure
    cmp ecx, 0
    jge .nonnegative
    xor ecx, ecx
.nonnegative:

    ; Read the digit (+ '0') to al
    mov edx, [bank]
    xor eax, eax
    mov al, [edx]

    ; Increment ecx until a smaller digit or the end of the selected digits is reached
.find_place_loop:
    cmp ecx, [selected_count]
    ja .failure
    je .find_place_loop_done
    cmp [esp+ecx], al
    jb .find_place_loop_done
    inc ecx
    jmp .find_place_loop

.find_place_loop_done:

    ; If the index ecx is within the capacity of the array, place the digit there and set the end
    ; of the array after it
    cmp ecx, [set_size]
    ja .failure
    je .skip_place
    mov [esp+ecx], al
    mov [selected_count], ecx
    inc dword [selected_count]
.skip_place:

    inc dword [bank]
    dec dword [bank_length]
    jmp .digit_loop
.digit_loop_done:

    ; Sanity check state
    mov eax, [selected_count]
    cmp eax, [set_size]
    jne .failure

    ; Parse digits from stack to return value edx:eax
    push esp
    call parse_ulong

    ; Free stack space for the array (except the 0-byte)
    add esp, [set_size]

    ; Check that the full array was parsed
    cmp ecx, esp
    jne .failure

    ; Free the 0-byte from stack
    inc esp

    add esp, %$localsize
    pop ebp
    ret 12

.failure:
    push 2
    call exit

    %pop


main:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local joltage1_low:dword
    %local joltage1_high:dword
    %local joltage2_low:dword
    %local joltage2_high:dword

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

    ; Initialize result joltages
    mov dword [joltage1_low], 0
    mov dword [joltage1_high], 0
    mov dword [joltage2_low], 0
    mov dword [joltage2_high], 0

    ; Loop through battery banks, generating the output joltages. esi = read position
    mov esi, input
.bank_loop:
    ; Break if we are out of input
    cmp byte [esi], 0
    je .bank_loop_done

    ; Find edi = end of bank
    mov edi, esi
.digit_loop:
    cmp byte [edi], `\n`
    je .digit_loop_done
    cmp byte [edi], '0'
    jl .parse_error
    cmp byte [edi], '9'
    jg .parse_error
    inc edi
    jmp .digit_loop
.digit_loop_done:

    ; Make edi the length of the bank
    sub edi, esi

    ; Add result joltages for this bank
    push dword 2
    push edi
    push esi
    call optimize_bank
    add [joltage1_low], eax
    adc [joltage1_high], edx
    push dword 12
    push edi
    push esi
    call optimize_bank
    add [joltage2_low], eax
    adc [joltage2_high], edx

    ; Continue the loop over banks
    add esi, edi
    inc esi
    jmp .bank_loop

.bank_loop_done:

    ; Write output to stdout
    push dword [joltage1_high]
    push dword [joltage1_low]
    call write_ulong_line_to_stdout
    push dword [joltage2_high]
    push dword [joltage2_low]
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
