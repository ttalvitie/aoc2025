global exit

%include "exit.inc"

exit:
    %push
    %stacksize flat
    %arg status:dword

    push ebp
    mov ebp, esp

    mov ebx, [status]
    mov eax, 1
    int 0x80

.loop:
    jmp .loop

    %pop
