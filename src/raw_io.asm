%include "raw_io.inc"

%include "exit.inc"


write_all_stdout:
    %push
    %stacksize flat

    %arg data_ptr:dword
    %arg data_size:dword

    push ebp
    mov ebp, esp

    push ebx

    cmp dword [data_size], 0
    je .done

.loop:
    mov eax, 4
    mov ebx, 1
    mov ecx, [data_ptr]
    mov edx, [data_size]
    int 0x80

    cmp eax, 0
    jle .failed
    cmp eax, [data_size]
    jg .failed
    je .done

    add [data_ptr], eax
    sub [data_size], eax
    jmp .loop

.done:
    pop ebx

    pop ebp
    ret 8

.failed:
    push 101
    call exit

    %pop


read_some_stdin:
    %push
    %stacksize flat

    %arg data_ptr:dword
    %arg data_capacity:dword

    push ebp
    mov ebp, esp

    push ebx

    mov eax, 3
    mov ebx, 0
    mov ecx, [data_ptr]
    mov edx, [data_capacity]
    int 0x80

    cmp eax, 0
    jl .failed
    cmp eax, [data_capacity]
    jg .failed

    pop ebx

    pop ebp
    ret 8

.failed:
    push 102
    call exit

    %pop


read_all_stdin:
    %push
    %stacksize flat

    %arg data_ptr:dword
    %arg data_capacity:dword

    %assign %$localsize 0
    %local read_size:dword

    push ebp
    mov ebp, esp
    sub esp, %$localsize

    mov dword [read_size], 0

.loop:
    cmp dword [data_capacity], 0
    jle .failed

    push dword [data_capacity]
    push dword [data_ptr]
    call read_some_stdin

    cmp eax, 0
    je .done

    cmp eax, [data_capacity]
    jg .failed

    add [data_ptr], eax
    sub [data_capacity], eax
    add [read_size], eax
    jmp .loop

.done:
    mov eax, [read_size]

    add esp, %$localsize
    pop ebp
    ret 8

.failed:
    push 103
    call exit

    %pop
