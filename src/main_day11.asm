extern main

%include "exit.inc"
%include "io.inc"
%include "math.inc"
%include "number_str.inc"
%include "raw_io.inc"


section .bss


input: resb 100000
input_capacity: equ $ - input

node_limit: equ 32 * 32 * 32
node_exists: resb node_limit
node_connection_count: resd node_limit
node_connections: resd node_limit

; -1 initially, -2 when in recursion stack
path_count_target: resd 1
path_count: resq node_limit

connections_buffer_capacity: equ 10000
connections_buffer: resd connections_buffer_capacity


section .text


init_path_counting:
    %push
    %stacksize flat

    %arg target:dword

    push ebp
    mov ebp, esp

    mov eax, [target]
    mov [path_count_target], eax

    xor eax, eax
.loop:
    cmp eax, node_limit
    jae .loop_done
    mov dword [path_count+8*eax], -1
    mov dword [path_count+8*eax+4], -1
    inc eax
    jmp .loop
.loop_done:

    pop ebp
    ret 4

    %pop


; (node index) -> (count low, count high)
compute_path_count:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local low:dword
    %local high:dword

    %arg node_idx:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    push ebx
    push edi
    push esi

    ; Handle the base case of the target node
    mov eax, [path_count_target]
    cmp dword [node_idx], eax
    jne .base_case_done
    mov eax, 1
    mov edx, 0
    jmp .done
.base_case_done:

    ; Check that the node is valid
    mov ebx, [node_idx]
    cmp byte [node_exists+ebx], 1
    jne .failure

    ; Check the path_count table, fail if it is -2 (a cycle) and return it if it is already
    ; computed
    mov eax, [path_count+8*ebx]
    mov edx, [path_count+8*ebx+4]
    cmp edx, -1
    jne .done
    cmp eax, -1
    jne .failure

    ; Compute the number of paths recursively; esi = node connections, edi = connection index
    mov dword [low], 0
    mov dword [high], 0
    mov esi, [node_connections+4*ebx]
    xor edi, edi
.connection_loop:
    cmp edi, [node_connection_count+4*ebx]
    ja .failure
    je .connection_loop_done
    push dword [esi+4*edi]
    call compute_path_count
    add [low], eax
    adc [high], edx
    inc edi
    jmp .connection_loop
.connection_loop_done:

    ; Save and return the computed value
    mov eax, [low]
    mov dword [path_count+8*ebx], eax
    mov edx, [high]
    mov dword [path_count+8*ebx+4], edx

.done:
    pop esi
    pop edi
    pop ebx

    add esp, %$localsize
    pop ebp
    ret 4

.failure:
    push 3
    call exit

    %pop


; (low1, high1, low2, high2) -> (low, high)
mul_ulong:
    %push
    %stacksize flat

    %arg low1:dword
    %arg high1:dword
    %arg low2:dword
    %arg high2:dword

    push ebp
    mov ebp, esp

    push esi
    push edi

    mov eax, [low1]
    mul dword [low2]
    mov esi, eax
    mov edi, edx
    mov eax, [low1]
    mul dword [high2]
    add edi, eax
    mov eax, [low2]
    mul dword [high1]
    add edi, eax

    mov eax, esi
    mov edx, edi

    pop edi
    pop esi

    pop ebp
    ret 16

    %pop


main:
    %push
    %stacksize flat

    %assign %$localsize 0
    %local svr_dac_low:dword
    %local svr_dac_high:dword
    %local svr_fft_low:dword
    %local svr_fft_high:dword
    %local dac_out_low:dword
    %local dac_out_high:dword
    %local fft_out_low:dword
    %local fft_out_high:dword
    %local dac_fft_low:dword
    %local dac_fft_high:dword
    %local fft_dac_low:dword
    %local fft_dac_high:dword

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

    ; Read input line by line; esi = read position, edi = connections_buffer index
    mov esi, input
    xor edi, edi
.input_line_loop:
    cmp byte [esi], 0
    je .input_line_loop_done

    ; Read node index to eax
    mov dl, [esi]
    inc esi
    sub dl, 'a'
    cmp dl, 'z' - 'a'
    ja .parse_error
    xor eax, eax
    mov al, dl
    mov dl, [esi]
    inc esi
    sub dl, 'a'
    cmp dl, 'z' - 'a'
    ja .parse_error
    shl eax, 5
    or al, dl
    mov dl, [esi]
    inc esi
    sub dl, 'a'
    cmp dl, 'z' - 'a'
    ja .parse_error
    shl eax, 5
    or al, dl

    ; Sanity check index
    cmp eax, node_limit
    jae .failure

    ; Check that the node does not exist yet
    cmp byte [node_exists+eax], 0
    jne .failure

    ; Initialize the node
    mov byte [node_exists+eax], 1
    mov dword [node_connection_count+4*eax], 0
    lea edx, [connections_buffer+4*edi]
    mov dword [node_connections+4*eax], edx

    ; Read the connections
    cmp byte [esi], ':'
    jne .parse_error
    inc esi
.input_connection_loop:
    cmp byte [esi], `\n`
    je .input_connection_loop_done

    cmp byte [esi], ' '
    jne .parse_error
    inc esi

    ; Read node index to ebx
    mov dl, [esi]
    inc esi
    sub dl, 'a'
    cmp dl, 'z' - 'a'
    ja .parse_error
    xor ebx, ebx
    mov bl, dl
    mov dl, [esi]
    inc esi
    sub dl, 'a'
    cmp dl, 'z' - 'a'
    ja .parse_error
    shl ebx, 5
    or bl, dl
    mov dl, [esi]
    inc esi
    sub dl, 'a'
    cmp dl, 'z' - 'a'
    ja .parse_error
    shl ebx, 5
    or bl, dl

    ; Sanity check index
    cmp ebx, node_limit
    jae .failure

    ; Add the connection
    cmp edi, connections_buffer_capacity
    jae .failure
    mov [connections_buffer+4*edi], ebx
    inc edi
    inc dword [node_connection_count+4*eax]

    ; Continue connection loop
    jmp .input_connection_loop
.input_connection_loop_done:
    inc esi

    ; Continue reading input lines
    jmp .input_line_loop
.input_line_loop_done:

    ; The out node is not listed explicitly, so make it exist too with 0 connections
    mov eax, 32 * (32 * ('o' - 'a') + ('u' - 'a')) + ('t' - 'a')
    mov byte [node_exists+eax], 1
    mov dword [node_connection_count+4*eax], 0

    ; Set out as the target node for path counting
    push 32 * (32 * ('o' - 'a') + ('u' - 'a')) + ('t' - 'a')
    call init_path_counting

    ; If node you exists, compute and print the number of paths for the first star
    cmp dword [node_exists+32 * (32 * ('y' - 'a') + ('o' - 'a')) + ('u' - 'a')], 1
    jne .first_star_done
    push 32 * (32 * ('y' - 'a') + ('o' - 'a')) + ('u' - 'a')
    call compute_path_count
    push edx
    push eax
    call write_ulong_line_to_stdout
.first_star_done:

    ; If we have node svr, solve also the second star
    cmp dword [node_exists+32 * (32 * ('s' - 'a') + ('v' - 'a')) + ('r' - 'a')], 1
    jne .done

    ; To solve the second star, find out the necessary subpath counts
    push 32 * (32 * ('d' - 'a') + ('a' - 'a')) + ('c' - 'a')
    call compute_path_count
    mov [dac_out_low], eax
    mov [dac_out_high], edx
    push 32 * (32 * ('f' - 'a') + ('f' - 'a')) + ('t' - 'a')
    call compute_path_count
    mov [fft_out_low], eax
    mov [fft_out_high], edx
    push 32 * (32 * ('d' - 'a') + ('a' - 'a')) + ('c' - 'a')
    call init_path_counting
    push 32 * (32 * ('s' - 'a') + ('v' - 'a')) + ('r' - 'a')
    call compute_path_count
    mov [svr_dac_low], eax
    mov [svr_dac_high], edx
    push 32 * (32 * ('f' - 'a') + ('f' - 'a')) + ('t' - 'a')
    call compute_path_count
    mov [fft_dac_low], eax
    mov [fft_dac_high], edx
    push 32 * (32 * ('f' - 'a') + ('f' - 'a')) + ('t' - 'a')
    call init_path_counting
    push 32 * (32 * ('s' - 'a') + ('v' - 'a')) + ('r' - 'a')
    call compute_path_count
    mov [svr_fft_low], eax
    mov [svr_fft_high], edx
    push 32 * (32 * ('d' - 'a') + ('a' - 'a')) + ('c' - 'a')
    call compute_path_count
    mov [dac_fft_low], eax
    mov [dac_fft_high], edx

    ; Obtain the path count using the subpath counts
    push dword [dac_fft_high]
    push dword [dac_fft_low]
    push dword [svr_dac_high]
    push dword [svr_dac_low]
    call mul_ulong
    push dword [fft_out_high]
    push dword [fft_out_low]
    push edx
    push eax
    call mul_ulong
    mov esi, eax
    mov edi, edx
    push dword [fft_dac_high]
    push dword [fft_dac_low]
    push dword [svr_fft_high]
    push dword [svr_fft_low]
    call mul_ulong
    push dword [dac_out_high]
    push dword [dac_out_low]
    push edx
    push eax
    call mul_ulong
    add eax, esi
    adc edx, edi
    push edx
    push eax
    call write_ulong_line_to_stdout

.done:
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

    %pop
