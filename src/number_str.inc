%ifndef NUMBER_STR_INC
%define NUMBER_STR_INC

; Parse unsigned integer from memory as long as there are numbers available.
; If there are no numbers, the pointer is unchanged and the result is 0.
; Does not check for overflow.
; (pointer to start) -> (result, pointer to end)
extern parse_uint

; Parse unsigned long integer from memory as long as there are numbers available.
; If there are no numbers, the pointer is unchanged and the result is 0.
; Does not check for overflow.
; (pointer to start) -> (low bits, high bits), also pointer to end in ecx
extern parse_ulong

; Write given unsigned integer as string to given memory block (aborts if capacity is too small).
; Does not write 0-byte to the end.
; (integer value, data pointer, data capacity) -> written length
extern uint_to_str

; Write given unsigned long integer as string to given memory block (aborts if capacity is too
; small). Does not write 0-byte to the end.
; (low bits, high bits, data pointer, data capacity) -> written length
extern ulong_to_str

%endif
