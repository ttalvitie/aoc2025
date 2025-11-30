%include "exit.inc"

global _start
extern main


_start:
    mov ebp, esp
    call main
    push eax
    call exit
