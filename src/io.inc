%ifndef IO_INC
%define IO_INC

; Write single line containing an unsigned integer to stdout
; (integer value) -> nothing
extern write_uint_line_to_stdout

; Write single line containing an unsigned long to stdout
; (low bits, high bits) -> nothing
extern write_ulong_line_to_stdout

%endif
