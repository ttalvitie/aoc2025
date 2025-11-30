%ifndef RAW_IO_INC
%define RAW_IO_INC

; Write all data to stdout
; (pointer to data, data size) -> nothing
extern write_all_stdout

; Read some data from stdin
; (pointer to data, data capacity) -> read size (0 if EOF)
extern read_some_stdin

; Read all stdin data (aborts if capacity is not larger than amount of data)
; (pointer to data, data capacity) -> read size
extern read_all_stdin

%endif
