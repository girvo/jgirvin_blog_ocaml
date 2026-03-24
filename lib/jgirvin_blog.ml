type dir = Posts | Pages | Templates

let dir_to_string = function
  | Posts -> "posts"
  | Pages -> "pages"
  | Templates -> "templates"

let contains_dir dir path =
  path |> Sys.readdir |> Array.exists (String.equal (dir_to_string dir))

let is_valid_input_dir path =
  List.for_all (fun d -> contains_dir d path) [ Posts; Pages; Templates ]

let is_valid_output_dir path = Sys.file_exists path && Sys.is_directory path
