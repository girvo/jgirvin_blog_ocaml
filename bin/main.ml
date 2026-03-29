open Jgirvin_blog

let input_dir = ref "."
let output_dir = ref "build"

let spec =
  [
    ("--input", Arg.Set_string input_dir, "<dir> Input path (default: .)");
    ("--output", Arg.Set_string output_dir, "<dir> Output path (default: build)");
  ]

type raw_post = { path : string; contents : string }

let fail msg =
  Format.eprintf "Error: %s@." msg;
  exit 1

let read_posts input_dir =
  Sys.readdir (dir_to_path input_dir Posts)
  |> Array.to_list
  |> List.filter (String.ends_with ~suffix:".md")
  |> List.map (fun file ->
      let path = get_file_path input_dir Posts file in
      let contents = In_channel.with_open_text path In_channel.input_all in
      { path; contents })

let make_post_output_dir output_dir (post : post) =
  let dirname = post_output_path output_dir post in
  if not (Sys.file_exists dirname) then Sys.mkdir dirname 0o755

let make_page_output_dir output_dir (page : page) =
  let dirname = page_output_path output_dir page in
  if not (String.equal dirname output_dir) then
    if not (Sys.file_exists dirname) then Sys.mkdir dirname 0o755

let () =
  let usage = "jgirvin_blog [options]" in
  Arg.parse spec
    (fun _ -> raise (Arg.Bad "unexpected anonymous argument"))
    usage;
  if String.equal !input_dir !output_dir then
    fail "input and output dirs can't be the same";
  if not (is_valid_input_dir !input_dir) then
    fail
      ("input directory must contain posts/ pages/ templates/ subdirectories: "
     ^ !input_dir);
  if not (is_valid_output_dir !output_dir) then
    fail ("output directory must exist and be a directory: " ^ !output_dir);
  if not (check_required_templates !input_dir) then
    fail "Could not find required templates";
  let raw_posts = read_posts !input_dir in
  let posts =
    List.map
      (fun { path; contents } -> parse_post ~file:path contents)
      raw_posts
    |> List.map
         (Result.map (fun (post : post) ->
              { post with body = parse_markdown_to_html post.body }))
  in
  Format.printf "Building output dirs for %d posts...@." (List.length posts);
  List.iter
    (fun p ->
      match p with Ok post -> make_post_output_dir !output_dir post | _ -> ())
    posts;
  List.iter
    (fun p ->
      match p with
      | Ok post -> Format.printf "%a@." pp_post post
      | Error e -> Format.printf "Error: %s@." e)
    posts;
  Format.printf "@.done@."
