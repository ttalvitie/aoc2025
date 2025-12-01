global parse_uint

%include "exit.inc"
%include "number.inc"


parse_uint:
    %push
    %stacksize flat

    %arg start_ptr:dword

    push ebp
    mov ebp, esp

    push esi

    ; eax = number, esi = position
    mov eax, 0
    mov esi, [start_ptr]
    mov ecx, 10
.loop:
    cmp byte [esi], '0'
    jl .done
    cmp byte [esi], '9'
    jg .done
    mul ecx
    xor edx, edx
    mov dl, [esi]
    add eax, edx
    sub eax, '0'
    inc esi
    jmp .loop

.done:
    mov edx, esi

    pop esi

    pop ebp
    ret 4

    %pop


uint_to_str:
    %push
    %stacksize flat

    %arg value:dword
    %arg data_ptr:dword
    %arg data_capacity:dword

    push ebp
    mov ebp, esp

    push ebx
    push esi
    push edi

    ; eax = remaining value prefix
    mov eax, [value]

    ; ebx = number of digits
    xor ebx, ebx

    ; Generate digits to stack
.loop:
    xor edx, edx
    mov ecx, 10
    div ecx
    add dl, '0'
    dec esp
    mov byte [esp], dl
    inc ebx

    cmp eax, 0
    jne .loop

    ; Check that we have enough capacity
    cmp ebx, [data_capacity]
    jg .failed

    ; Copy digits from stack to the output data
    mov ecx, ebx
    mov esi, esp
    mov edi, [data_ptr]
    rep movsb

    ; Clear digits from stack
    add esp, ebx

    ; Return the number of digits
    mov eax, ebx

    pop edi
    pop esi
    pop ebx

    pop ebp
    ret 12

.failed:
    push 104
    call exit

    %pop
