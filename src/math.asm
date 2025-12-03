%include "math.inc"


div_ulong_by_uint:
    %push
    %stacksize flat

    %arg a_low:dword
    %arg a_high:dword
    %arg b:dword

    push ebp
    mov ebp, esp

    ; First compute a_high / b to eax and a_high % b to edx
    mov eax, [a_high]
    xor edx, edx
    div dword [b]

    ; Reduce to the case where we replace a_high by a_high % b. We just need to add
    ; a_high / b to the high bits of the resulting quotient (stored in ecx).
    ; resulting quotient.
    mov ecx, eax
    mov [a_high], edx

    ; Compute a_high:a_low / b to eax and a_high:a_low % b to edx. The quotient won't overflow
    ; as we ensured in the previous reduction that a_high < b and thus a_high:a_low < b:0.
    mov edx, [a_high]
    mov eax, [a_low]
    div dword [b]

    ; Swap the stored high bits of the quotient in ecx and the remainder from the last division in
    ; edx so that the return values are in correct registers.
    xchg ecx, edx

    pop ebp
    ret 12

    %pop
