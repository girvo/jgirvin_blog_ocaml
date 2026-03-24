type dir = Posts | Pages | Templates

val dir_to_string : dir -> string
(** Converts a dir to a string representation *)

val contains_dir : dir -> string -> bool
(** Check if a directory contains a given subdirectory *)

val is_valid_input_dir : string -> bool
(** Checks if the directory has all needed dir folders in it *)

val is_valid_output_dir : string -> bool
