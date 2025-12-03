%include "number_str.inc"

%include "exit.inc"
%include "math.inc"


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


parse_ulong:
    %push
    %stacksize flat

    %arg start_ptr:dword

    push ebp
    mov ebp, esp

    push esi
    push edi
    push ebx

    ; ebx = low, edi = high
    xor ebx, ebx
    xor edi, edi

    ; esi = position
    mov esi, [start_ptr]
.loop:
    ; End loop if character [esi] is not a number
    cmp byte [esi], '0'
    jl .done
    cmp byte [esi], '9'
    jg .done

    ; Multiply edi:ebx by 10
    mov eax, ebx
    mov ecx, 10
    mul ecx
    mov ebx, eax
    mov eax, edi
    mov edi, edx
    mul ecx
    add edi, eax

    ; Add the number in [esi] to edi:ebx
    xor edx, edx
    mov dl, [esi]
    sub edx, '0'
    add ebx, edx
    adc edi, 0

    ; Continue to next character
    inc esi
    jmp .loop

.done:
    ; Arrange return values
    mov eax, ebx
    mov edx, edi
    mov ecx, esi

    pop ebx
    pop edi
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

    push dword [data_capacity]
    push dword [data_ptr]
    push dword 0
    push dword [value]
    call ulong_to_str

    pop ebp
    ret 12

    %pop


ulong_to_str:
    %push
    %stacksize flat

    %arg low:dword
    %arg high:dword
    %arg data_ptr:dword
    %arg data_capacity:dword

    push ebp
    mov ebp, esp

    push ebx
    push esi
    push edi

    ; ebx = number of digits
    xor ebx, ebx

    ; Generate digits to stack
.loop:
    push 10
    push dword [high]
    push dword [low]
    call div_ulong_by_uint
    mov [low], eax
    mov [high], edx
    add cl, '0'
    dec esp
    mov byte [esp], cl
    inc ebx

    cmp dword [low], 0
    jne .loop
    cmp dword [high], 0
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
    ret 16

.failed:
    push 104
    call exit

    %pop
