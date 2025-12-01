%include "exit.inc"

global _start
extern main


_start:
    mov ebp, esp

    ; Set callee-saved registers and stack top to known values so that we can later check that
    ; main follows calling conventions
    push 0x2bcc2125
    mov ebx, 0x9273b49b
    mov esi, 0x725c2b12
    mov edi, 0x8e013a96

    call main

    ; Check that the registers are as expected after the call
    pop edx
    cmp edx, 0x2bcc2125
    jne .failed
    cmp ebx, 0x9273b49b
    jne .failed
    cmp esi, 0x725c2b12
    jne .failed
    cmp edi, 0x8e013a96
    jne .failed
    mov edx, esp
    cmp ebp, esp
    jne .failed

    push eax
    call exit

.failed:
    push 105
    call exit
