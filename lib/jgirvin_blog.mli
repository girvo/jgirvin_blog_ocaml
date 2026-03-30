type dir = Posts | Pages | Templates | Assets

type post_meta = {
  title : string;
  slug : string;
  author : string;
  date : string;
  draft : bool; [@default false]
  description : string option;
}
[@@deriving eq, show, of_yaml]

type page_meta = {
  title : string;
  draft : bool; [@default false]
  description : string option;
}
[@@deriving eq, show, of_yaml]

type post = { file : string; body : string; meta : post_meta }
[@@deriving eq, show]

type page = { file : string; body : string; meta : page_meta }
[@@deriving eq, show]

val dir_to_string : dir -> string
(** Converts a dir to a string representation *)

val contains_dir : dir -> string -> bool
(** Check if a directory contains a given subdirectory *)

val is_valid_input_dir : string -> bool
(** Checks if the directory has all needed dir folders in it *)

val is_valid_output_dir : string -> bool

val dir_to_path : string -> dir -> string
(** Takes input path, dir and gives concatted path *)

val get_file_path : string -> dir -> string -> string
(** Takes input path, dir, and file name to give full concatenated path *)

val parse_post : file:string -> string -> (post, string) result
val parse_page : file:string -> string -> (page, string) result
val parse_markdown_to_html : string -> string
val check_required_templates : string -> bool
val post_output_path : string -> post -> string
val page_output_path : string -> page -> string
val slug_to_link : string -> string
val page_to_slug : page -> string
