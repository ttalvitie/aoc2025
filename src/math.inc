%ifndef MATH_INC
%define MATH_INC

; Compute the floor of the division of a long unsigned integer a by unsigned integer b
; (a low bits, a high bits, b) -> (quotient low bits, quotient high bits), also remainder in ecx
extern div_ulong_by_uint

%endif
