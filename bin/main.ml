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

let tag_to_value tags =
  List.map
    (fun tag ->
      let tag_obj =
        Object.empty
        |> Object.add "name" (String tag)
        |> Object.add "link" (String ("/tags/" ^ tag))
      in
      Object tag_obj)
    tags

let build_post_items posts =
  List.map
    (fun (post : post) ->
      Object
        (Object.empty
        |> Object.add "title" (String post.meta.title)
        |> Object.add "slug" (String post.meta.slug)
        |> Object.add "link" (String (slug_to_link post.meta.slug))
        |> Object.add "date" (String post.meta.date)
        |> Object.add "body" (String post.body)
        |> Object.add "tags" (List (tag_to_value post.meta.tags))
        |> Object.add "description"
             (Option.fold ~none:Nil
                ~some:(fun s -> String s)
                post.meta.description)))
    posts

let read_template input_dir file =
  let path = get_file_path input_dir Templates file in
  In_channel.with_open_text path In_channel.input_all

let read_template_opt input_dir file =
  try Some (read_template input_dir file) with _ -> None

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

let render_archive ~input_dir ~output_dir post_items =
  let template = read_template input_dir "archive.liquid" in
  let ctx =
    Ctx.empty |> add_base_ctx
    |> Ctx.add "title" (String "Archive")
    |> Ctx.add "all_posts" (List post_items)
  in
  let settings =
    Settings.make
      ~template_directory:(dir_to_path input_dir Templates)
      ~context:ctx ()
  in
  let html = Liquid.render_text ~settings template in
  let archive_dir = Filename.concat output_dir "archive" in
  if not (Sys.file_exists archive_dir) then Sys.mkdir archive_dir 0o755;
  Out_channel.with_open_text (Filename.concat archive_dir "index.html")
    (fun oc -> output_string oc html)

let render_feed ~input_dir ~output_dir post_items =
  let template = read_template input_dir "feed.xml.liquid" in
  let ctx =
    Ctx.empty |> add_base_ctx
    |> Ctx.add "title" (String "Feed")
    |> Ctx.add "recent_posts"
         (List (List.filteri (fun i _ -> i < 10) post_items))
  in
  let settings =
    Settings.make
      ~template_directory:(dir_to_path input_dir Templates)
      ~context:ctx ()
  in
  let xml = Liquid.render_text ~settings template in
  Out_channel.with_open_text (Filename.concat output_dir "feed.xml") (fun oc ->
      output_string oc xml)

let render_sitemap ~input_dir ~output_dir ~post_items ~page_items posts_by_tags =
  let template = read_template input_dir "sitemap.xml.liquid" in
  let tag_items =
    List.map
      (fun (tag, posts) ->
        Object
          (Object.empty
          |> Object.add "name" (String tag)
          |> Object.add "link" (String ("/tags/" ^ tag ^ "/"))))
      posts_by_tags
  in
  let ctx =
    Ctx.empty |> add_base_ctx
    |> Ctx.add "title" (String "Sitemap")
    |> Ctx.add "all_posts" (List post_items)
    |> Ctx.add "all_pages" (List page_items)
    |> Ctx.add "all_tags" (List tag_items)
  in
  let settings =
    Settings.make
      ~template_directory:(dir_to_path input_dir Templates)
      ~context:ctx ()
  in
  let xml = Liquid.render_text ~settings template in
  Out_channel.with_open_text (Filename.concat output_dir "sitemap.xml")
    (fun oc -> output_string oc xml)

let render_index ~input_dir ~output_dir (posts : post list) =
  let template = read_template input_dir "index.liquid" in
  let latest_post =
    match posts with
    | [] -> Nil
    | post :: _ ->
        Object
          (Object.empty
          |> Object.add "title" (String post.meta.title)
          |> Object.add "slug" (String post.meta.slug)
          |> Object.add "link" (String (slug_to_link post.meta.slug))
          |> Object.add "date" (String post.meta.date)
          |> Object.add "description"
               (Option.fold ~none:Nil
                  ~some:(fun s -> String s)
                  post.meta.description)
          |> Object.add "body" (String post.body))
  in
  let ctx =
    Ctx.empty |> add_base_ctx
    |> Ctx.add "title" (String "Home")
    |> Ctx.add "latest_post" latest_post
  in
  let settings =
    Settings.make
      ~template_directory:(dir_to_path input_dir Templates)
      ~context:ctx ()
  in
  let html = Liquid.render_text ~settings template in
  Out_channel.with_open_text (Filename.concat output_dir "index.html")
    (fun oc -> output_string oc html)

let render_404 ~input_dir ~output_dir =
  let template = read_template input_dir "404.liquid" in
  let ctx = Ctx.empty |> add_base_ctx |> Ctx.add "title" (String "Not found") in
  let settings =
    Settings.make
      ~template_directory:(dir_to_path input_dir Templates)
      ~context:ctx ()
  in
  let html = Liquid.render_text ~settings template in
  Out_channel.with_open_text (Filename.concat output_dir "404.html") (fun oc ->
      output_string oc html)

let render_tags_index ~input_dir ~output_dir posts_by_tags =
  let template = read_template input_dir "tags.liquid" in
  let tag_items =
    List.map
      (fun (tag, posts) ->
        Object
          (Object.empty
          |> Object.add "name" (String tag)
          |> Object.add "link" (String ("/tags/" ^ tag ^ "/"))
          |> Object.add "count" (String (string_of_int (List.length posts)))))
      posts_by_tags
  in
  let ctx =
    Ctx.empty |> add_base_ctx
    |> Ctx.add "title" (String "Tags")
    |> Ctx.add "all_tags" (List tag_items)
  in
  let settings =
    Settings.make
      ~template_directory:(dir_to_path input_dir Templates)
      ~context:ctx ()
  in
  let html = Liquid.render_text ~settings template in
  let tags_dir = Filename.concat output_dir "tags" in
  if not (Sys.file_exists tags_dir) then Sys.mkdir tags_dir 0o755;
  Out_channel.with_open_text (Filename.concat tags_dir "index.html")
    (fun oc -> output_string oc html)

let render_tags ~input_dir ~output_dir posts_by_tags =
  let template = read_template input_dir "archive.liquid" in
  let tags_dir = Filename.concat output_dir "tags" in
  if not (Sys.file_exists tags_dir) then Sys.mkdir tags_dir 0o755;
  List.iter
    (fun (tag, posts) ->
      let tag_dir = Filename.concat tags_dir tag in
      if not (Sys.file_exists tag_dir) then Sys.mkdir tag_dir 0o755;
      let post_items = build_post_items posts in
      let ctx =
        Ctx.empty |> add_base_ctx
        |> Ctx.add "title" (String ("Tag: " ^ tag))
        |> Ctx.add "all_posts" (List post_items)
      in
      let settings =
        Settings.make
          ~template_directory:(dir_to_path input_dir Templates)
          ~context:ctx ()
      in
      let html = Liquid.render_text ~settings template in
      Out_channel.with_open_text (Filename.concat tag_dir "index.html")
        (fun oc -> output_string oc html))
    posts_by_tags

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
      (Printf.sprintf "input directory %s is missing required subdirectories"
         !input_dir);
  if not (is_valid_output_dir !output_dir) then
    fail ("output directory must exist and be a directory: " ^ !output_dir);
  if not (check_required_templates !input_dir) then
    fail "Could not find required templates";
  let raw_posts = read_all_content ~kind:Posts ~suffix:".md" !input_dir in
  let posts =
    List.filter_map
      (fun { path; contents } ->
        match parse_post ~file:path contents with
        | Ok (post : post) when not post.meta.draft ->
            Some { post with body = parse_markdown_to_html post.body }
        | Error e ->
            Printf.eprintf "Failed to parse post %s: %s\n" path e;
            None
        | _ -> None)
      raw_posts
    |> sort_by_date
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
        |> Ctx.add "tags" (List (tag_to_value post.meta.tags))
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
    List.filter_map
      (fun { path; contents } ->
        match parse_page ~file:path contents with
        | Ok (page : page) when not page.meta.draft -> Some page
        | Error e ->
            Printf.eprintf "Failed to parse page %s: %s\n" path e;
            None
        | _ -> None)
      raw_pages
  in
  Format.printf "Building output dirs for %d pages...@." (List.length pages);
  List.iter (fun page -> make_page_output_dir !output_dir page) pages;
  let post_items = build_post_items posts in
  let page_items =
    List.map
      (fun (page : page) ->
        let slug = page_to_slug page in
        Object (Object.empty |> Object.add "link" (String (slug_to_link slug))))
      pages
  in
  Format.printf "Rendering pages...@.";
  List.iter
    (fun (page : page) ->
      let ctx =
        Ctx.empty |> add_base_ctx
        |> Ctx.add "title" (String page.meta.title)
        |> Ctx.add "description"
             (Option.fold ~none:Nil
                ~some:(fun s -> String s)
                page.meta.description)
        |> Ctx.add "input_file" (String page.file)
        |> Ctx.add "link" (String (page |> page_to_slug |> slug_to_link))
      in
      let settings =
        Settings.make
          ~template_directory:(dir_to_path !input_dir Templates)
          ~log_policy:Never () ~context:ctx
      in
      render_page ~settings ~template:page.body ~output_dir:!output_dir page)
    pages;

  Format.printf "Rendering index...@.";
  render_index ~input_dir:!input_dir ~output_dir:!output_dir posts;
  Format.printf "Rendering archive...@.";
  render_archive ~input_dir:!input_dir ~output_dir:!output_dir post_items;
  Format.printf "Collecting tags...@.";
  let posts_by_tags = group_by_tag posts in
  Format.printf "Rendering tags...@.";
  render_tags ~input_dir:!input_dir ~output_dir:!output_dir posts_by_tags;
  Format.printf "Rendering tags index...@.";
  render_tags_index ~input_dir:!input_dir ~output_dir:!output_dir posts_by_tags;
  Format.printf "Rendering RSS feed...@.";
  render_feed ~input_dir:!input_dir ~output_dir:!output_dir post_items;
  Format.printf "Rendering sitemap...@.";
  render_sitemap ~input_dir:!input_dir ~output_dir:!output_dir ~post_items
    ~page_items posts_by_tags;
  Format.printf "Rendering 404...@.";
  render_404 ~input_dir:!input_dir ~output_dir:!output_dir;
  Format.printf "Copying assets directory over...@.";
  copy_assets !input_dir !output_dir;
  Format.printf "@.Done@."
