type dir = Posts | Pages | Templates

type post_meta = {
  title : string;
  slug : string;
  author : string;
  date : string;
  draft : bool; [@default false]
  description : string option;
}
[@@deriving eq, show, of_yaml ~skip_unknown]

type post = { file : string; body : string; meta : post_meta }
[@@deriving eq, show]

let dir_to_string = function
  | Posts -> "posts"
  | Pages -> "pages"
  | Templates -> "templates"

let contains_dir dir path =
  path |> Sys.readdir |> Array.exists (String.equal (dir_to_string dir))

let is_valid_input_dir path =
  List.for_all (fun d -> contains_dir d path) [ Posts; Pages; Templates ]

let is_valid_output_dir path = Sys.file_exists path && Sys.is_directory path
let dir_to_path path dir = Filename.concat path (dir_to_string dir)
let get_file_path path dir file = Filename.concat (dir_to_path path dir) file

let parse_post ~file input =
  match Frontmatter_extractor_yaml.of_string input with
  | Error (`Msg e) -> Error e
  | Ok { attrs = None; _ } -> Error "No frontmatter found"
  | Ok { attrs = Some attrs; body } -> (
      match post_meta_of_yaml attrs with
      | Error (`Msg e) -> Error e
      | Ok meta -> Ok { file; body; meta })

let parse_markdown_to_html body =
  let doc = Cmarkit.Doc.of_string ~strict:false body in
  Cmarkit_html.of_doc ~safe:true doc

let check_required_templates path =
  let required_templates = [ "post.liquid"; "archive.liquid" ] in
  List.for_all
    (fun file ->
      let full_path = get_file_path path Templates file in
      if Sys.file_exists full_path then true
      else (
        Format.printf "Can't find required template: %s@." full_path;
        false))
    required_templates
