open Jgirvin_blog
open Liquid_ml
open Liquid_ml.Exports

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

(** This handles the pages/index.liquid base case properly *)
let make_page_output_dir output_dir (page : page) =
  let dirname = page_output_path output_dir page in
  if not (String.equal dirname output_dir) then
    if not (Sys.file_exists dirname) then Sys.mkdir dirname 0o755

let read_template input_dir file =
  let path = get_file_path input_dir Templates file in
  In_channel.with_open_text path In_channel.input_all

let render_post ~settings ~template ~output_dir (post : post) =
  let html = Liquid.render_text ~settings template in
  let output_file =
    Filename.concat (post_output_path output_dir post) "index.html"
  in
  Out_channel.with_open_text output_file (fun oc -> output_string oc html)

(** Might add more to this later?*)
let add_base_ctx = Ctx.add "site_title" (String "jgirvin.com")

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
    |> List.filter (fun r ->
        match r with Ok (post : post) -> not post.meta.draft | Error e -> true)
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
  let post_template = read_template !input_dir "post.liquid" in
  List.iter
    (fun p ->
      match p with
      | Ok (post : post) ->
          let ctx =
            Ctx.empty |> add_base_ctx
            |> Ctx.add "title" (String post.meta.title)
            |> Ctx.add "slug" (String post.meta.slug)
            |> Ctx.add "author" (String post.meta.author)
            |> Ctx.add "date" (String post.meta.date)
            |> Ctx.add "description"
                 (Option.fold ~none:Nil
                    ~some:(fun s -> String s)
                    post.meta.description)
            |> Ctx.add "body" (String post.body)
            |> Ctx.add "input_file" (String post.file)
          in
          let settings =
            Settings.make
              ~template_directory:(dir_to_path !input_dir Templates)
              ~log_policy:Verbose () ~context:ctx
          in
          render_post ~settings ~template:post_template ~output_dir:!output_dir
            post
      | _ -> Format.printf "Skipping...@.")
    posts;
  Format.printf "@.done@."
