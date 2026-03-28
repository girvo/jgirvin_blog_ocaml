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
  let raw_posts = read_posts !input_dir in
  let posts =
    List.map
      (fun { path; contents } -> parse_post ~file:path contents)
      raw_posts
  in
  List.iter
    (fun p ->
      match p with
      | Ok post -> Format.printf "%a@." pp_post post
      | Error e -> Format.printf "Error: %s@." e)
    posts;
  Format.printf "done@."
