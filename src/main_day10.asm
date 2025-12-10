extern main

%include "exit.inc"
%include "io.inc"
%include "math.inc"
%include "number_str.inc"
%include "raw_io.inc"


section .bss


input: resb 100000
input_capacity: equ $ - input

target: resd 1
width: resd 1

buttons_capacity: equ 16
buttons: resd buttons_capacity
buttons_count: resd 1

joltages: resd 32


section .text


solve_first_star:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local combination:dword
    %local combination_size:dword
    %local best_count:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    push ebx

    ; Initialize result
    mov dword [best_count], -1

    ; Try all combinations of buttons to press
    cmp dword [buttons_count], 0
    je .failure
    cmp dword [buttons_count], 32
    jae .failure
    mov dword [combination], 1
    mov cl, [buttons_count]
    shl dword [combination], cl
.combination_loop:
    dec dword [combination]

    ; Simulate the button presses to check whether they result in the correct pattern;
    ; eax = current pattern, edx = button index, ebx = button bit
    xor eax, eax
    xor edx, edx
    mov ebx, 1
    mov dword [combination_size], 0
.button_loop:
    cmp edx, [buttons_count]
    ja .failure
    je .button_loop_done
    test [combination], ebx
    jz .update_done
    xor eax, [buttons+4*edx]
    inc dword [combination_size]
.update_done:
    inc edx
    shl ebx, 1
    jmp .button_loop
.button_loop_done:

    ; If the pattern is correct, update [best_count]
    cmp eax, [target]
    jne .combination_loop_continue

    mov eax, [combination_size]
    cmp eax, [best_count]
    jae .combination_loop_continue
    mov dword [best_count], eax

.combination_loop_continue:
    ; Continue the loop over combinations
    cmp dword [combination], 0
    jne .combination_loop

    ; Return the smallest number of button presses that works
    mov eax, [best_count]

    pop ebx

    add esp, %$localsize
    pop ebp
    ret

.failure:
    push 3
    call exit

    %pop


main:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local result1:dword

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

    ; Initialize result variable
    mov dword [result1], 0

    ; Loop through the lines in the input; esi = read position
    mov esi, input
.input_loop:
    cmp byte [esi], 0
    je .input_loop_done

    ; Read the target pattern in [target] and its width in [width]; edi = current bit
    cmp byte [esi], '['
    jne .failure
    inc esi
    mov dword [target], 0
    mov dword [width], 0
    mov edi, 1
.target_bit_loop:
    cmp byte [esi], ']'
    je .target_bit_loop_done
    cmp edi, 0
    je .failure
    inc dword [width]
    cmp byte [esi], '.'
    je .bit_update_done
    cmp byte [esi], '#'
    jne .failure
    or [target], edi
.bit_update_done:
    shl edi, 1
    inc esi
    jmp .target_bit_loop
.target_bit_loop_done:
    inc esi
    cmp byte [esi], ' '
    jne .failure
    inc esi

    ; Read buttons in a loop
    mov dword [buttons_count], 0
.buttons_loop:
    cmp byte [esi], '('
    jne .buttons_loop_done
    cmp dword [buttons_count], buttons_capacity
    jae .failure

    ; Read mask for button in a loop
    mov edi, [buttons_count]
    mov dword [buttons+4*edi], 0
.button_mask_loop:
    inc esi
    push esi
    call parse_uint
    mov esi, edx
    cmp eax, [width]
    jae .failure
    mov edx, 1
    mov cl, al
    shl edx, cl
    test dword [buttons+4*edi], edx
    jnz .failure
    or dword [buttons+4*edi], edx
    cmp byte [esi], ','
    je .button_mask_loop

    cmp byte [esi], ')'
    jne .failure
    inc esi
    cmp byte [esi], ' '
    jne .failure
    inc esi
    inc dword [buttons_count]
    jmp .buttons_loop
.buttons_loop_done:

    ; Read joltage requirements in a loop; edi = joltage index
    cmp dword [width], 0
    je .failure
    cmp byte [esi], '{'
    jne .failure
    inc esi
    xor edi, edi
.joltage_loop:
    push esi
    call parse_uint
    mov esi, edx
    mov [joltages+4*edi], eax
    inc edi
    cmp edi, [width]
    ja .failure
    je .joltage_loop_done
    cmp byte [esi], ','
    jne .failure
    inc esi
    jmp .joltage_loop
.joltage_loop_done:
    cmp byte [esi], '}'
    jne .failure
    inc esi
    cmp byte [esi], `\n`
    jne .failure
    inc esi

    ; Solve the optimization problem for tihs input line, accumulating result
    call solve_first_star
    add [result1], eax

    jmp .input_loop
.input_loop_done:

    ; Write result
    push dword [result1]
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

    %pop
