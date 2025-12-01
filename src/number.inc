%ifndef NUMBER_INC
%define NUMBER_INC

; Parse unsigned integer from memory as long as there are numbers available.
; If there are no numbers, the pointer is unchanged and the result is 0.
; (pointer to start) -> (result, pointer to end)
extern parse_uint

; Write given unsigned integer as string to given memory block (aborts if capacity is too small).
; Does not write 0-byte to the end.
; (integer value, data pointer, data capacity) -> written length
extern uint_to_str

%endif
