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
button_sizes: resd buttons_capacity
buttons_count: resd 1

joltages: resd 32

max_button_size: resd 32


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


compute_heuristic:
    %push
    %stacksize flat

    %arg remaining_button_mask:dword

    %assign %$localsize 0
    %local result:dword
    %local result2:dword
    %local result_frac:dword
    %local max_joltage:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    push edi
    push esi
    push ebx

    ; For each joltage, compute the size of the largest remaining button mask containing it
    ; (store result in array max_button_size)
    xor edi, edi
.max_button_size_clear_loop:
    cmp edi, [width]
    ja .failure
    je .max_button_size_clear_loop_done
    mov dword [max_button_size+4*edi], 0
    inc edi
    jmp .max_button_size_clear_loop
.max_button_size_clear_loop_done:
    xor ecx, ecx
.max_button_size_loop:
    cmp ecx, [buttons_count]
    ja .failure
    je .max_button_size_loop_done
    mov edx, 1
    shl edx, cl
    test [remaining_button_mask], edx
    jz .max_button_size_loop_continue
    mov esi, ecx
    push ecx
    xor ecx, ecx
.max_button_size_joltage_loop:
    cmp ecx, [width]
    ja .failure
    je .max_button_size_joltage_loop_done
    mov edx, 1
    shl edx, cl
    test [buttons+4*esi], edx
    jz .max_button_size_joltage_loop_continue
    mov eax, [button_sizes+4*esi]
    cmp eax, [max_button_size+4*ecx]
    jbe .max_button_size_joltage_loop_continue
    mov [max_button_size+4*ecx], eax
.max_button_size_joltage_loop_continue:
    inc ecx
    jmp .max_button_size_joltage_loop
.max_button_size_joltage_loop_done:
    pop ecx
.max_button_size_loop_continue:
    inc ecx
    jmp .max_button_size_loop
.max_button_size_loop_done:

    ; Compute the heuristic as the ceiling function of the sum over all joltages of the joltage
    ; divided by the size of the largest remaining button mask containing it. The fractional part
    ; of the heuristic are in [result_frac]
    mov dword [result], 0
    mov dword [result_frac], 0
    xor edi, edi
.loop:
    cmp edi, [width]
    ja .failure
    je .loop_done

    ; Skip zero joltages
    cmp dword [joltages+4*edi], 0
    je .loop_continue

    ; If the nonzero joltage is not in any remaining button, return infinity (-1)
    cmp dword [max_button_size+4*edi], 0
    jne .dead_end_check_done
    mov dword [result], -1
    jmp .done
.dead_end_check_done:

    ; Accumulate the heuristic
    push dword [max_button_size+4*edi]
    push dword [joltages+4*edi]
    push 0
    call div_ulong_by_uint
    add [result_frac], eax
    adc [result], edx

.loop_continue:
    ; Continue loop over joltages
    inc edi
    jmp .loop
.loop_done:

    ; If the fractional bits are nonzero, increase the result for the ceiling function
    cmp dword [result_frac], 0
    je .ceil_done
    inc dword [result]
.ceil_done:

    ; In some cases, improve the heuristic by making it at least as large as each joltage
    mov dword [max_joltage], 0
    xor edi, edi
.max_heuristic_loop:
    cmp edi, [width]
    ja .failure
    je .max_heuristic_loop_done
    mov eax, [joltages+4*edi]
    cmp eax, [max_joltage]
    jbe .max_heuristic_loop_continue
    mov [max_joltage], eax
.max_heuristic_loop_continue:
    inc edi
    jmp .max_heuristic_loop
.max_heuristic_loop_done:
    mov eax, [max_joltage]
    cmp eax, [result]
    jbe .max_joltage_result_update_done
    mov [result], eax
.max_joltage_result_update_done:

    ; For each joltage, compute the size of the largest complement of a button mask containing it
    ; (store result in array max_button_size)
    xor edi, edi
.max_button_size_clear_loop2:
    cmp edi, [width]
    ja .failure
    je .max_button_size_clear_loop_done2
    mov dword [max_button_size+4*edi], 0
    inc edi
    jmp .max_button_size_clear_loop2
.max_button_size_clear_loop_done2:
    xor ecx, ecx
.max_button_size_loop2:
    cmp ecx, [buttons_count]
    ja .failure
    je .max_button_size_loop_done2
    mov edx, 1
    shl edx, cl
    test [remaining_button_mask], edx
    jz .max_button_size_loop_continue2
    mov esi, ecx
    push ecx
    xor ecx, ecx
.max_button_size_joltage_loop2:
    cmp ecx, [width]
    ja .failure
    je .max_button_size_joltage_loop_done2
    mov edx, 1
    shl edx, cl
    test [buttons+4*esi], edx
    jnz .max_button_size_joltage_loop_continue2
    mov eax, [width]
    sub eax, [button_sizes+4*esi]
    cmp eax, [max_button_size+4*ecx]
    jbe .max_button_size_joltage_loop_continue2
    mov [max_button_size+4*ecx], eax
.max_button_size_joltage_loop_continue2:
    inc ecx
    jmp .max_button_size_joltage_loop2
.max_button_size_joltage_loop_done2:
    pop ecx
.max_button_size_loop_continue2:
    inc ecx
    jmp .max_button_size_loop2
.max_button_size_loop_done2:

    ; Compute complement-side heuristic to result2
    mov dword [result2], 0
    mov dword [result_frac], 0
    xor edi, edi
.loop2:
    cmp edi, [width]
    ja .failure
    je .loop_done2

    ; Skip zero complement joltages
    mov eax, [max_joltage]
    sub eax, [joltages+4*edi]
    cmp eax, 0
    je .loop_continue2

    ; If the nonzero joltage is not in any remaining button, return infinity (-1)
    cmp dword [max_button_size+4*edi], 0
    jne .dead_end_check_done2
    mov dword [result], -1
    jmp .done
.dead_end_check_done2:

    ; Accumulate the heuristic
    push dword [max_button_size+4*edi]
    mov eax, [max_joltage]
    sub eax, [joltages+4*edi]
    push eax
    push 0
    call div_ulong_by_uint
    add [result_frac], eax
    adc [result2], edx

.loop_continue2:
    ; Continue loop over joltages
    inc edi
    jmp .loop2
.loop_done2:

    ; If the fractional bits are nonzero, increase the result for the ceiling function
    cmp dword [result_frac], 0
    je .ceil_done2
    inc dword [result2]
.ceil_done2:

    ; If result2 is better than result, update result
    mov eax, [result2]
    cmp eax, [result]
    jbe .complement_update_done
    mov [result], eax
.complement_update_done:

.done:
    ; Return value
    mov eax, [result]

    pop ebx
    pop esi
    pop edi

    add esp, %$localsize
    pop ebp
    ret 4

.failure:
    push 4
    call exit

    %pop


search:
    %push
    %stacksize flat

    %arg limit:dword
    %arg remaining_button_mask:dword

    %assign %$localsize 0
    %local max_joltage:dword
    %local button_idx:dword
    %local button_joltage_mask:dword
    %local max_press_count:dword
    %local current_press_count:dword
    %local result:dword
    %local once_mask:dword
    %local twice_mask:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    push ebx
    push esi
    push edi

    ; Set defalt result to 0 (failure)
    mov dword [result], 0

    ; Compute the maximum (remainder) joltage
    mov dword [max_joltage], 0
    xor edi, edi
.max_joltage_loop:
    cmp edi, [width]
    ja .failure
    je .max_joltage_loop_done
    mov eax, [joltages+4*edi]
    cmp eax, [max_joltage]
    jbe .max_joltage_loop_continue
    mov [max_joltage], eax
.max_joltage_loop_continue:
    inc edi
    jmp .max_joltage_loop
.max_joltage_loop_done:

    ; If the maximum joltage is 0, we are already done
    cmp dword [max_joltage], 0
    jne .finished_check_done
    mov dword [result], 1
    jmp .done
.finished_check_done:

    ; Remove unpressable buttons from the mask
    xor edi, edi
.reduce_button_loop:
    cmp edi, [buttons_count]
    ja .failure
    je .reduce_button_loop_done
    mov ecx, edi
    mov edx, 1
    shl edx, cl
    test [remaining_button_mask], edx
    jz .reduce_button_loop_continue
    xor ebx, ebx
.reduce_joltage_loop:
    cmp ebx, [width]
    ja .failure
    je .reduce_button_loop_continue
    mov ecx, ebx
    mov edx, 1
    shl edx, cl
    test [buttons+4*edi], edx
    jz .reduce_joltage_loop_continue
    cmp dword [joltages+4*ebx], 0
    jz .reduce_remaining_button_mask
.reduce_joltage_loop_continue:
    inc ebx
    jmp .reduce_joltage_loop
.reduce_remaining_button_mask:
    mov ecx, edi
    mov edx, 1
    shl edx, cl
    xor [remaining_button_mask], edx
.reduce_button_loop_continue:
    inc edi
    jmp .reduce_button_loop
.reduce_button_loop_done:

    ; Compute heuristic lower bound for the distance to all zeros
    push dword [remaining_button_mask]
    call compute_heuristic

    ; If the heuristic is larger than the limit, give up
    cmp eax, dword [limit]
    ja .done

    ; Create mask of joltages that occur in exactly one remaining button
    mov dword [once_mask], 0
    mov dword [twice_mask], 0
    xor edi, edi
.once_loop:
    cmp edi, [buttons_count]
    ja .failure
    je .once_loop_done
    mov ecx, edi
    mov edx, 1
    shl edx, cl
    test [remaining_button_mask], edx
    jz .once_loop_continue
    mov edx, [buttons+4*edi]
    mov eax, edx
    and eax, [once_mask]
    or [twice_mask], eax
    or [once_mask], edx
.once_loop_continue:
    inc edi
    jmp .once_loop
.once_loop_done:
    mov eax, [twice_mask]
    xor [once_mask], eax

    ; Pick the button, prioritized first by picking buttons that are the last containing a certain
    ; joltage and then picking buttons with largest masks overall (to make the heuristic work
    ; better, as it works better for smaller masks)
    mov dword [button_idx], -1
    xor ecx, ecx
.button_pick_loop:
    cmp ecx, [buttons_count]
    ja .failure
    je .button_pick_loop_done
    mov edx, 1
    shl edx, cl
    test [remaining_button_mask], edx
    jz .button_pick_loop_continue
    cmp dword [button_idx], -1
    je .pick_this_button
    mov edx, [button_idx]
    mov edx, [buttons+4*edx]
    test edx, [once_mask]
    jz .old_not_closing
    mov edx, [buttons+4*ecx]
    test edx, [once_mask]
    jnz .compare_sizes
    jmp .button_pick_loop_continue
.old_not_closing:
    mov edx, [buttons+4*ecx]
    test edx, [once_mask]
    jnz .pick_this_button
.compare_sizes:
    mov edx, [button_idx]
    mov edx, [button_sizes+4*edx]
    cmp [button_sizes+4*ecx], edx
    jbe .button_pick_loop_continue
.pick_this_button:
    mov [button_idx], ecx
.button_pick_loop_continue:
    inc ecx
    jmp .button_pick_loop
.button_pick_loop_done:
    cmp dword [button_idx], -1
    je .failure
    mov ecx, [button_idx]
    mov edx, 1
    shl edx, cl
    xor dword [remaining_button_mask], edx
    mov eax, [buttons+4*ecx]
    mov [button_joltage_mask], eax

    ; Compute how many times we can press the button
    mov eax, [limit]
    mov dword [max_press_count], eax
    xor ecx, ecx
.max_press_count_loop:
    cmp ecx, [width]
    ja .failure
    je .max_press_count_loop_done
    mov edx, 1
    shl edx, cl
    test [button_joltage_mask], edx
    jz .max_press_count_loop_continue
    mov eax, [joltages+4*ecx]
    cmp eax, [max_press_count]
    jae .max_press_count_loop_continue
    mov [max_press_count], eax
.max_press_count_loop_continue:
    inc ecx
    jmp .max_press_count_loop
.max_press_count_loop_done:

    ; Consider each button press count (edi)
    xor edi, edi
.press_loop:
    ; Save press count to local variable to enable restore
    mov [current_press_count], edi

    ; Recursively consider the subproblem after pressing this button edi times and disabling it
    ; (it has been removed from remaining_button_mask)
    push dword [remaining_button_mask]
    push dword [limit]
    sub dword [esp], edi
    call search

    ; If the subproblem was solved successfully, then return success here too
    cmp eax, 0
    je .success_check_done
    mov dword [result], 1
    jmp .restore_joltages
.success_check_done:

    ; Continue to next button press count unless we have reached the limit
    inc edi
    cmp edi, [max_press_count]
    ja .press_loop_done
    xor ecx, ecx
.add_press_loop:
    cmp ecx, [width]
    ja .failure
    je .add_press_loop_done
    mov edx, 1
    shl edx, cl
    test [button_joltage_mask], edx
    jz .add_press_loop_continue
    dec dword [joltages+4*ecx]
.add_press_loop_continue:
    inc ecx
    jmp .add_press_loop
.add_press_loop_done:
    jmp .press_loop
.press_loop_done:

    ; Restore original joltages
.restore_joltages:
    xor ecx, ecx
.restore_press_loop:
    cmp ecx, [width]
    ja .failure
    je .restore_press_loop_done
    mov edx, 1
    shl edx, cl
    test [button_joltage_mask], edx
    jz .restore_press_loop_continue
    mov eax, [current_press_count]
    add [joltages+4*ecx], eax
.restore_press_loop_continue:
    inc ecx
    jmp .restore_press_loop
.restore_press_loop_done:

.done:
    ; Return value
    mov eax, [result]

    pop edi
    pop esi
    pop ebx

    add esp, %$localsize
    pop ebp
    ret 8

.failure:
    push 3
    call exit

    %pop


solve_second_star:
    %push
    %stacksize flat

    push ebp
    mov ebp, esp

    push ebx
    push esi

    ; Generate full button mask (esi)
    mov esi, 1
    mov ecx, [buttons_count]
    shl esi, cl
    dec esi

    ; Use iterative deepening A* to find the minimum number of button presses (ebx)
    xor ebx, ebx
.loop:
    push esi
    push ebx
    call search
    cmp eax, 0
    jne .loop_done
    inc ebx
    jmp .loop
.loop_done:
    mov eax, ebx

    pop esi
    pop ebx

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
    %local result2:dword

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

    ; Initialize result variables
    mov dword [result1], 0
    mov dword [result2], 0

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
    mov dword [button_sizes+4*edi], 0
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
    inc dword [button_sizes+4*edi]
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

    ; Solve the optimization problems for this input line, accumulating results. To make second
    ; star solving faster, order the buttons before it
    call solve_first_star
    add [result1], eax

    call solve_second_star
    add [result2], eax

    ;push eax
    ;call write_uint_line_to_stdout

    jmp .input_loop
.input_loop_done:

    ; Write results
    push dword [result1]
    call write_uint_line_to_stdout
    push dword [result2]
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
