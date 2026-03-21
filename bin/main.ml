let contains_posts_dir path =
  path
  |> Sys.readdir
  |> Array.exists (String.equal "posts")

let usage_message = "jgirvin_blog [options]"
let input_dir = ref "."
let output_dir = ref "build"

let spec = [
  "--input", Arg.Set_string input_dir, "<dir> Input path (default: .)";
  "--output", Arg.Set_string output_dir, "<dir> Output path (default: build)";
]

let () =
  Arg.parse spec (fun _ -> raise (Arg.Bad "no valid arguments")) usage_message;
  if !input_dir = !output_dir then raise (Arg.Bad "input and output dirs can't be equal");
  Printf.printf "input=%s output=%s\n" !input_dir !output_dir;
  Printf.printf "has posts in input: %b\n" (contains_posts_dir !input_dir);
;;
  (* let path = if !path = "" then "." else !path in
  Printf.printf "%b\n" (contains_posts_dir path) *)
