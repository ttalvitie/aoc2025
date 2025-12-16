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

buttons_capacity: equ 13
buttons: resd buttons_capacity
button_sizes: resd buttons_capacity
buttons_count: resd 1

joltages_capacity: equ 14
joltages: resd joltages_capacity
joltages_count: resd 1

; Prime modulus used for modular arithmetic
M: equ (1 << 31) - 1

; Augmented matrix representing the equation that the joltages resulting from the button presses
; must match the joltages (the variables to solve are the button press counts). The matrix is
; converted to row echelon form with each leading entry 1 with Gaussian elimination using modular
; arithmetic.
matrix_stride_bytes: equ 4 * (buttons_capacity + 1)
matrix: resb joltages_capacity * matrix_stride_bytes
matrix_rows: equ joltages_count
matrix_cols: equ buttons_count ; not including last column, as the matrix is augmented

; After gauss_elimination, for each column the pointer to the row where the leading element is in
; that column or 0 if there is no such row
leading_element_col_to_row_ptr: resd buttons_capacity

; In search, the current number of button presses and the best found
current_total_presses: resd 1
best_total_presses: resd 1

; The current assignment of button presses so far in search
button_press_counts: resd buttons_capacity

tmp_capacity: equ 32
tmp: resb tmp_capacity


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
    cmp dword [buttons_count], joltages_capacity
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


; (a, b) -> (a + b) % M
mod_add:
    %push
    %stacksize flat

    %arg a:dword
    %arg b:dword

    push ebp
    mov ebp, esp

    cmp dword [a], M
    jae .failure
    cmp dword [b], M
    jae .failure

    mov eax, [a]
    add eax, [b]
    cmp eax, M
    jb .done
    sub eax, M
.done:

    pop ebp
    ret 8

.failure:
    push 4
    call exit

    %pop


; (a, b) -> (a - b) % M
mod_sub:
    %push
    %stacksize flat

    %arg a:dword
    %arg b:dword

    push ebp
    mov ebp, esp

    cmp dword [a], M
    jae .failure
    cmp dword [b], M
    jae .failure

    mov eax, [a]
    sub eax, [b]
    cmp eax, 0
    jge .done
    add eax, M
.done:

    pop ebp
    ret 8

.failure:
    push 5
    call exit

    %pop


; (a, b) -> (a * b) % M
mod_mul:
    %push
    %stacksize flat

    %arg a:dword
    %arg b:dword

    push ebp
    mov ebp, esp

    cmp dword [a], M
    jae .failure
    cmp dword [b], M
    jae .failure

    mov eax, [a]
    mul dword [b]

    push dword M
    push edx
    push eax
    call div_ulong_by_uint
    mov eax, ecx

    pop ebp
    ret 8

.failure:
    push 6
    call exit

    %pop


mod_inv:
    %push
    %stacksize flat

    %arg x:dword

    push ebp
    mov ebp, esp

    push esi
    push edi
    push ebx

    ; Compute modular multiplicative inverse of x by raising it to power M-2 (Fermat's little theorem);
    ; edi = x ** (1 << a), esi = (M - 2) >> a (looping over a = 0, 1, ...), ebx = result
    mov edi, [x]
    mov esi, M - 2
    mov ebx, 1
.power_loop:
    test esi, 1
    jz .accumulate_done
    push ebx
    push edi
    call mod_mul
    mov ebx, eax
.accumulate_done:
    shr esi, 1
    cmp esi, 0
    je .power_loop_done
    push edi
    push edi
    call mod_mul
    mov edi, eax
    jmp .power_loop
.power_loop_done:

    mov eax, ebx

    pop ebx
    pop edi
    pop esi

    pop ebp
    ret 4

.failure:
    push 14
    call exit

    %pop


print_matrix:
    %push
    %stacksize flat

    push ebp
    mov ebp, esp

    push ebx
    push esi
    push edi

    ; Iterate over matrix elements; ebx = row, esi = column, edi = row start
    xor ebx, ebx
    mov edi, matrix
.rows_loop:
    cmp ebx, [matrix_rows]
    ja .failure
    je .rows_loop_done
    xor esi, esi
.elems_loop:
    mov eax, [matrix_cols]
    inc eax
    cmp esi, eax
    ja .failure
    je .elems_loop_done
    push edi
    mov edi, tmp
    mov ecx, 6
    mov al, ' '
    rep stosb
    pop edi
    push dword tmp_capacity - 6
    push dword tmp + 6
    push dword [edi+4*esi]
    call uint_to_str
    xor edx, edx
    cmp eax, 6
    jae .padding_done
    mov edx, 6
    sub edx, eax
.padding_done:
    push eax
    add dword [esp], edx
    push dword tmp + 6
    sub dword [esp], edx
    call write_all_stdout
    inc esi
    jmp .elems_loop
.elems_loop_done:
    mov byte [tmp], `\n`
    push 1
    push dword tmp
    call write_all_stdout
    inc ebx
    add edi, matrix_stride_bytes
    jmp .rows_loop
.rows_loop_done:
    mov byte [tmp], `\n`
    push 1
    push dword tmp
    call write_all_stdout

    pop edi
    pop esi
    pop ebx

    pop ebp
    ret

.failure:
    push 8
    call exit

    %pop


; Given (source row, target row, coef), add source row multiplied by coef to target row
add_row:
    %push
    %stacksize flat

    %arg source_row:dword
    %arg target_row:dword
    %arg coef:dword

    push ebp
    mov ebp, esp

    push ebx
    push esi
    push edi

    ; Loop over the two rows in sync
    ; esi = source row position, edi = target row position, ebx = column
    xor ebx, ebx
    mov eax, matrix_stride_bytes
    mul dword [source_row]
    lea esi, [matrix+eax]
    mov eax, matrix_stride_bytes
    mul dword [target_row]
    lea edi, [matrix+eax]
.loop:
    push dword [esi]
    push dword [coef]
    call mod_mul
    push dword [edi]
    push eax
    call mod_add
    mov [edi], eax

    ; Continue looping over the rows
    inc ebx
    add esi, 4
    add edi, 4
    cmp ebx, [matrix_cols]
    jbe .loop

    pop edi
    pop esi
    pop ebx

    pop ebp
    ret 12

.failure:
    push 10
    call exit

    %pop


; Apply Gaussian elimination to the augmented matrix to bring it into row echelon form wih leading
; elements 1. Returns the number of nonzero rows (the rank) in the main matrix.
gauss_elimination:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local rows_done:dword
    %local remaining_rows_start:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    push ebx
    push esi
    push edi

    ; Initialize variables to keep track of the completed rows in the elimination
    mov dword [rows_done], 0
    mov dword [remaining_rows_start], matrix

    ; Clear the leading element information
    mov ecx, [matrix_cols]
    mov edi, leading_element_col_to_row_ptr
    xor eax, eax
    rep stosd

    ; Loop over columns in the non-augmented part of the matrix; esi = column
    xor esi, esi
.main_column_loop:
    cmp esi, [matrix_cols]
    ja .failure
    je .main_column_loop_done

    ; Stop if all rows are already done
    mov eax, [rows_done]
    cmp eax, [matrix_rows]
    ja .failure
    je .main_column_loop_done

    ; Find the first nonzero element on this column in the remaining rows;
    ; ebx = row, edi = pointer to element
    mov ebx, [rows_done]
    cmp ebx, [matrix_rows]
    mov edi, [remaining_rows_start]
    lea edi, [edi+4*esi]
.find_first_nonzero_loop:
    cmp ebx, [matrix_rows]
    ja .failure
    je .main_column_loop_continue
    cmp dword [edi], 0
    jne .first_nonzero_found
    inc ebx
    add edi, matrix_stride_bytes
    jmp .find_first_nonzero_loop

.first_nonzero_found:
    ; Nonzero element found, add that row to the first remaining row
    push 1
    push dword [rows_done]
    push ebx
    call add_row
    ; Jump back to the first remaining row
    mov ebx, [rows_done]
    mov edi, [remaining_rows_start]
    lea edi, [edi+4*esi]

    ; Make the leading element of this row 1 by dividing the row by the current leading element
    mov eax, [edi]
    cmp eax, 0
    je .failure
    push eax
    call mod_inv
    push 1
    push eax
    call mod_sub
    push eax
    push ebx
    push ebx
    call add_row
    cmp dword [edi], 1
    jne .failure

    ; Make the next elements on this column zero by subtracting the first remaining row scaled
    ; from them; ebx = row, edi = pointer to element
.clear_column_loop:
    inc ebx
    add edi, matrix_stride_bytes
    cmp ebx, [matrix_rows]
    ja .failure
    je .clear_column_loop_done
    mov eax, [edi]
    cmp eax, 0
    je .clear_column_loop_continue
    push eax
    push 0
    call mod_sub
    push eax
    push ebx
    push dword [rows_done]
    call add_row
    cmp dword [edi], 0
    jne .failure
.clear_column_loop_continue:
    jmp .clear_column_loop
.clear_column_loop_done:

    ; Now one more row is done; save the leading element information and advance the local variables
    mov eax, matrix_stride_bytes
    mul dword [rows_done]
    add eax, matrix
    mov dword [leading_element_col_to_row_ptr+4*esi], eax
    inc dword [rows_done]
    add dword [remaining_rows_start], matrix_stride_bytes

.main_column_loop_continue:
    ; Continue main loop over columns
    inc esi
    jmp .main_column_loop
.main_column_loop_done:

    ; Return the rank
    mov eax, [rows_done]

    pop edi
    pop esi
    pop ebx

    add esp, %$localsize
    pop ebp
    ret

.failure:
    push 9
    call exit

    %pop


; Recursively search for solutions, considering the valid assignments of button presses to [count]
; first buttons (using the modular arithmetic matrix system to reduce the amount of cases to
; consider). Maintains the current remainder joltages in the joltages array, the button press
; counts in button_press_counts and [current_total_presses] and [best_total_presses].
search:
    %push
    %stacksize flat

    %arg count:dword

    %assign %$localsize 0
    %local button_idx:dword
    %local max_press_count:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    push esi
    push edi

    cmp dword [count], 0
    jne .count_nonzero

    ; Base case: accept the result if the remainder joltages are 0; otherwise, return immediately
    xor edi, edi
.accept_check_loop:
    cmp edi, [joltages_count]
    je .accept_check_loop_done
    cmp dword [joltages+4*edi], 0
    jne .done
    inc edi
    jmp .accept_check_loop
.accept_check_loop_done:

    ; All result joltages are zero, pdate the best total presses and return
    mov eax, [current_total_presses]
    cmp eax, [best_total_presses]
    jae .done
    mov [best_total_presses], eax
    jmp .done

    ; Other cases, where we still have to choose press counts for buttons with indexes from
    ; [count] - 1 down to 0
.count_nonzero:
    mov eax, [count]
    cmp eax, [buttons_count]
    ja .failure
    dec eax
    mov [button_idx], eax

    ; First, compute the maximum number of presses for this button
    mov dword [max_press_count], -1
    xor ecx, ecx
.maximum_press_count_loop:
    cmp ecx, [joltages_count]
    ja .failure
    je .maximum_press_count_loop_done
    mov edx, 1
    shl edx, cl
    mov eax, [button_idx]
    test [buttons+4*eax], edx
    jz .maximum_press_count_loop_continue
    mov eax, [joltages+4*ecx]
    cmp eax, [max_press_count]
    jae .maximum_press_count_loop_continue
    mov [max_press_count], eax
.maximum_press_count_loop_continue:
    inc ecx
    jmp .maximum_press_count_loop
.maximum_press_count_loop_done:

    mov eax, [button_idx]
    cmp dword [leading_element_col_to_row_ptr+4*eax], 0
    je .free_variable

    ; The case where the number of presses for this button can be computed using back-substitution
    ; in the augmented matrix

    ; Check that the leading element is 1
    mov eax, [button_idx]
    mov edx, [leading_element_col_to_row_ptr+4*eax]
    cmp dword [edx+4*eax], 1
    jne .failure

    ; Start generating the number of presses (esi) from the value in the augmented column
    mov eax, [button_idx]
    mov eax, [leading_element_col_to_row_ptr+4*eax]
    mov edx, [matrix_cols]
    mov esi, [eax+4*edx]

    ; Then loop over the other columns after [button_idx], subtracting the button press counts
    ; multiplied by the matrix elements; edi = column index
    mov edi, [button_idx]
.back_substitution_loop:
    inc edi
    cmp edi, [matrix_cols]
    ja .failure
    je .back_substitution_loop_done
    push dword [button_press_counts+4*edi]
    mov eax, [button_idx]
    mov eax, [leading_element_col_to_row_ptr+4*eax]
    push dword [eax+4*edi]
    call mod_mul
    push eax
    push esi
    call mod_sub
    mov esi, eax
    jmp .back_substitution_loop
.back_substitution_loop_done:

    ; If the resulting button press count is impossible, return
    cmp esi, [max_press_count]
    ja .done

    ; Otherwise, apply the button press to button_press_counts, current_total_presses and joltages
    mov eax, [button_idx]
    mov [button_press_counts+4*eax], esi
    add [current_total_presses], esi
    xor ecx, ecx
.apply_button_press_loop:
    cmp ecx, [joltages_count]
    ja .failure
    je .apply_button_press_loop_done
    mov edx, 1
    shl edx, cl
    mov eax, [button_idx]
    test [buttons+4*eax], edx
    jz .apply_button_press_loop_continue
    sub dword [joltages+4*ecx], esi
.apply_button_press_loop_continue:
    inc ecx
    jmp .apply_button_press_loop
.apply_button_press_loop_done:

    ; Recursively search over assignments of press counts to the rest of the buttons
    push dword [button_idx]
    call search

    ; Revert the effects of the button press to current_total_presses and joltages
    sub [current_total_presses], esi
    xor ecx, ecx
.revert_button_press_loop:
    cmp ecx, [joltages_count]
    ja .failure
    je .revert_button_press_loop_done
    mov edx, 1
    shl edx, cl
    mov eax, [button_idx]
    test [buttons+4*eax], edx
    jz .revert_button_press_loop_continue
    add dword [joltages+4*ecx], esi
.revert_button_press_loop_continue:
    inc ecx
    jmp .revert_button_press_loop
.revert_button_press_loop_done:

    ; The back-substitution case is now handled
    jmp .done

    ; The case where the number of presses for this button is not fixed by the back-substitution
    ; and thus we need to consider all possible values
.free_variable:

    ; Loop over button press counts
    mov eax, [button_idx]
    mov dword [button_press_counts+4*eax], 0
.button_press_count_loop:

    ; Recursively search over assignments of press counts to the rest of the buttons
    push dword [button_idx]
    call search

    ; Continue loop over button press counts
    mov edx, [button_idx]
    mov eax, [max_press_count]
    cmp dword [button_press_counts+4*edx], eax
    ja .failure
    je .button_press_count_loop_done
    inc dword [button_press_counts+4*edx]
    xor ecx, ecx
.press_button_loop:
    cmp ecx, [joltages_count]
    ja .failure
    je .press_button_loop_done
    mov edx, 1
    shl edx, cl
    mov eax, [button_idx]
    test [buttons+4*eax], edx
    jz .press_button_loop_continue
    dec dword [joltages+4*ecx]
.press_button_loop_continue:
    inc ecx
    jmp .press_button_loop
.press_button_loop_done:
    inc dword [current_total_presses]
    jmp .button_press_count_loop
.button_press_count_loop_done:

    ; Revert the effects of the button presses on joltages and current_total_presses
    mov eax, [max_press_count]
    sub [current_total_presses], eax
    xor ecx, ecx
.unpress_button_loop:
    cmp ecx, [joltages_count]
    ja .failure
    je .unpress_button_loop_done
    mov edx, 1
    shl edx, cl
    mov eax, [button_idx]
    test [buttons+4*eax], edx
    jz .unpress_button_loop_continue
    mov eax, [max_press_count]
    add dword [joltages+4*ecx], eax
.unpress_button_loop_continue:
    inc ecx
    jmp .unpress_button_loop
.unpress_button_loop_done:

.done:
    pop edi
    pop esi

    add esp, %$localsize
    pop ebp
    ret 4

.failure:
    push 13
    call exit

    %pop


solve_second_star:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local rank:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    push ebx
    push esi
    push edi

    ; Initialize matrix; ebx = row, esi = column, edi = row start
    xor ebx, ebx
    mov edi, matrix
.matrix_init_rows_loop:
    cmp ebx, [matrix_rows]
    ja .failure
    je .matrix_init_rows_loop_done
    xor esi, esi
.matrix_init_elems_loop:
    cmp esi, [buttons_count]
    ja .failure
    je .matrix_init_elems_loop_done
    mov dword [edi+4*esi], 0
    mov edx, 1
    mov ecx, ebx
    shl edx, cl
    test [buttons+4*esi], edx
    jz .elem_init_done
    inc dword [edi+4*esi]
.elem_init_done:
    inc esi
    jmp .matrix_init_elems_loop
.matrix_init_elems_loop_done:
    mov eax, [joltages+4*ebx]
    cmp eax, M
    jae .failure
    mov [edi+4*esi], eax
    inc ebx
    add edi, matrix_stride_bytes
    jmp .matrix_init_rows_loop
.matrix_init_rows_loop_done:

    ; Use Gauss elimination to reduce the matrix to row echelon form
    call gauss_elimination
    mov [rank], eax

    ;call print_matrix

    ; Check that the augmented column is all zeros in the rows where the main matrix is zero; this
    ; is required for the system to be solvable; ebx = row, edi = position
    mov ebx, [rank]
    mov eax, matrix_stride_bytes
    mul ebx
    mov edx, [matrix_cols]
    lea edi, [matrix+4*edx+eax]
.solvable_check_loop:
    cmp ebx, [matrix_rows]
    ja .failure
    je .solvable_check_loop_done
    cmp dword [edi], 0
    jne .system_not_solvable
    inc ebx
    add edi, matrix_stride_bytes
    jmp .solvable_check_loop
.solvable_check_loop_done:

    ; Initialize state variables for search
    mov dword [current_total_presses], 0
    mov dword [best_total_presses], -1

    ; Recursively search for minimum number of button presses
    push dword [buttons_count]
    call search

    ; Check that state was reverted correctly
    cmp dword [current_total_presses], 0
    jne .failure

    ; Check that we found a solution
    cmp dword [best_total_presses], -1
    je .solution_not_found

    ; Return minimum number of total presses
    mov eax, [best_total_presses]

    pop edi
    pop esi
    pop ebx

    add esp, %$localsize
    pop ebp
    ret

.failure:
    push 3
    call exit

.system_not_solvable:
    push 11
    call exit

.solution_not_found:
    push 12
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

    ; Read the target pattern in [target] and its width in [joltages_count]; edi = current bit
    cmp byte [esi], '['
    jne .failure
    inc esi
    mov dword [target], 0
    mov dword [joltages_count], 0
    mov edi, 1
.target_bit_loop:
    cmp byte [esi], ']'
    je .target_bit_loop_done
    cmp edi, 0
    je .failure
    inc dword [joltages_count]
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
    cmp eax, [joltages_count]
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
    cmp dword [joltages_count], 0
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
    cmp edi, [joltages_count]
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
