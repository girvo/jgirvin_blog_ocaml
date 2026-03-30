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

type raw_content = { path : string; contents : string }

let fail msg =
  Format.eprintf "Error: %s@." msg;
  exit 1

let read_all_content ~kind:dir ~suffix input_dir =
  Sys.readdir (dir_to_path input_dir dir)
  |> Array.to_list
  |> List.filter (String.ends_with ~suffix)
  |> List.map (fun file ->
      let path = get_file_path input_dir dir file in
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

let render_page ~settings ~template ~output_dir (page : page) =
  let html = Liquid.render_text ~settings template in
  let output_file =
    Filename.concat (page_output_path output_dir page) "index.html"
  in
  Out_channel.with_open_text output_file (fun oc -> output_string oc html)

(** Might add more to this later? *)
let add_base_ctx ctx =
  ctx
  |> Ctx.add "site_title" (String "jgirvin.com")
  |> Ctx.add "site_url" (String "https://jgirvin.com")

let copy_file source dest =
  let ic = In_channel.open_bin source in
  let oc = Out_channel.open_bin dest in
  let buf = Bytes.create 4096 in
  let rec loop () =
    let n = In_channel.input ic buf 0 (Bytes.length buf) in
    if n > 0 then begin
      Out_channel.output oc buf 0 n;
      loop ()
    end
  in
  loop ();
  In_channel.close ic;
  Out_channel.close oc

let rec copy_dir_contents source_dir dest_dir =
  if not (Sys.file_exists dest_dir) then Sys.mkdir dest_dir 0o755;
  Sys.readdir source_dir
  |> Array.iter (fun entry ->
      let source = Filename.concat source_dir entry in
      let dest = Filename.concat dest_dir entry in
      if Sys.is_directory source then copy_dir_contents source dest
      else copy_file source dest)

let copy_assets input_dir output_dir =
  let assets_path = dir_to_path input_dir Assets in
  let output_path = Filename.concat output_dir "assets" in
  copy_dir_contents assets_path output_path

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
  let raw_posts = read_all_content ~kind:Posts ~suffix:".md" !input_dir in
  let posts =
    List.map
      (fun { path; contents } -> parse_post ~file:path contents)
      raw_posts
    |> List.filter_map (function
      | Ok (post : post) when not post.meta.draft ->
          Some { post with body = parse_markdown_to_html post.body }
      | Error e ->
          Printf.eprintf "Failed to parse: %s\n" e;
          None
      | _ -> None)
    |> List.sort (fun (a : post) (b : post) ->
        String.compare b.meta.date a.meta.date)
  in
  Format.printf "Building output dirs for %d posts...@." (List.length posts);
  List.iter (fun post -> make_post_output_dir !output_dir post) posts;
  Format.printf "Rendering posts...@.";
  let post_template = read_template !input_dir "post.liquid" in
  List.iter
    (fun (post : post) ->
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
        |> Ctx.add "link" (String (slug_to_link post.meta.slug))
      in
      let settings =
        Settings.make
          ~template_directory:(dir_to_path !input_dir Templates)
          ~log_policy:Never () ~context:ctx
      in
      render_post ~settings ~template:post_template ~output_dir:!output_dir post)
    posts;

  let raw_pages = read_all_content ~kind:Pages ~suffix:".liquid" !input_dir in
  let pages =
    List.map
      (fun { path; contents } -> parse_page ~file:path contents)
      raw_pages
    |> List.filter (fun r ->
        match r with Ok (page : page) -> not page.meta.draft | Error e -> true)
  in
  Format.printf "Building output dirs for %d pages...@." (List.length pages);
  List.iter
    (fun p ->
      match p with Ok page -> make_page_output_dir !output_dir page | _ -> ())
    pages;
  let post_items =
    List.map
      (fun (post : post) ->
        Object
          (Object.empty
          |> Object.add "title" (String post.meta.title)
          |> Object.add "slug" (String post.meta.slug)
          |> Object.add "link" (String (slug_to_link post.meta.slug))
          |> Object.add "date" (String post.meta.date)
          |> Object.add "description"
               (Option.fold ~none:Nil
                  ~some:(fun s -> String s)
                  post.meta.description)))
      posts
  in
  Format.printf "Rendering pages...@.";
  List.iter
    (fun p ->
      match p with
      | Ok (page : page) ->
          let ctx =
            Ctx.empty |> add_base_ctx
            |> Ctx.add "title" (String page.meta.title)
            |> Ctx.add "description"
                 (Option.fold ~none:Nil
                    ~some:(fun s -> String s)
                    page.meta.description)
            |> Ctx.add "input_file" (String page.file)
            |> Ctx.add "link" (String (page |> page_to_slug |> slug_to_link))
            |> Ctx.add "recent_posts"
                 (List (List.filteri (fun i _ -> i < 5) post_items))
          in
          let settings =
            Settings.make
              ~template_directory:(dir_to_path !input_dir Templates)
              ~log_policy:Never () ~context:ctx
          in
          render_page ~settings ~template:page.body ~output_dir:!output_dir page
      | Error e -> Format.printf "Skipping page due to: %s @." e)
    pages;

  Format.printf "Rendering archive...@.";
  let archive_template = read_template !input_dir "archive.liquid" in
  let archive_ctx =
    Ctx.empty |> add_base_ctx |> Ctx.add "all_posts" (List post_items)
  in
  let archive_settings =
    Settings.make
      ~template_directory:(dir_to_path !input_dir Templates)
      ~context:archive_ctx ()
  in
  let archive_html =
    Liquid.render_text ~settings:archive_settings archive_template
  in
  let archive_dir = Filename.concat !output_dir "archive" in
  if not (Sys.file_exists archive_dir) then Sys.mkdir archive_dir 0o755;
  Out_channel.with_open_text (Filename.concat archive_dir "index.html")
    (fun oc -> output_string oc archive_html);
  Format.printf "Rendering RSS feed...@.";
  let feed_template = read_template !input_dir "feed.xml.liquid" in
  let feed_ctx =
    Ctx.empty |> add_base_ctx
    |> Ctx.add "recent_posts"
         (List (List.filteri (fun i _ -> i < 10) post_items))
  in
  let feed_settings =
    Settings.make
      ~template_directory:(dir_to_path !input_dir Templates)
      ~context:feed_ctx ()
  in
  let feed_xml = Liquid.render_text ~settings:feed_settings feed_template in
  Out_channel.with_open_text (Filename.concat !output_dir "feed.xml") (fun oc ->
      output_string oc feed_xml);
  Format.printf "Copying assets directory over...@.";
  copy_assets !input_dir !output_dir;
  Format.printf "@.Done@."
