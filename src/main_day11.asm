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
path_count: resq node_limit

connections_buffer_capacity: equ 10000
connections_buffer: resd connections_buffer_capacity


section .text


; (node index) -> (count low, count high)
compute_path_count:
    %push
    %stacksize flat

    %arg node_idx:dword

    push ebp
    mov ebp, esp

    push ebx
    push edi
    push esi

    ; Handle the base case of node "out"
    cmp dword [node_idx], 32 * (32 * ('o' - 'a') + ('u' - 'a')) + ('t' - 'a')
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

    ; Compute the number of paths to qword [path_count+8_ebx] recursively; esi = node connections,
    ; edi = connection index
    mov dword [path_count+8*ebx], 0
    mov dword [path_count+8*ebx+4], 0
    mov esi, [node_connections+4*ebx]
    xor edi, edi
.connection_loop:
    cmp edi, [node_connection_count+4*ebx]
    ja .failure
    je .connection_loop_done
    push dword [esi+4*edi]
    call compute_path_count
    add [path_count+8*ebx], eax
    add [path_count+8*ebx+4], edx
    inc edi
    jmp .connection_loop
.connection_loop_done:

    ; Return the computed value
    mov eax, [path_count+8*ebx]
    mov edx, [path_count+8*ebx+4]

.done:
    pop esi
    pop edi
    pop ebx

    pop ebp
    ret 4

.failure:
    push 3
    call exit

    %pop


main:
    %push
    %stacksize flat

    %assign %$localsize 0

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
    mov dword [path_count+8*eax], -1
    mov dword [path_count+8*eax+4], -1

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

    ; Compute and print the number of paths
    push 32 * (32 * ('y' - 'a') + ('o' - 'a')) + ('u' - 'a')
    call compute_path_count
    push edx
    push eax
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

    %pop
