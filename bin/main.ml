let input_dir = ref "."
let output_dir = ref "build"

let spec =
  [
    ("--input", Arg.Set_string input_dir, "<dir> Input path (default: .)");
    ("--output", Arg.Set_string output_dir, "<dir> Output path (default: build)");
  ]

let () =
  let usage = "jgirvin_blog [options]" in
  Arg.parse spec
    (fun _ -> raise (Arg.Bad "unexpected anonymous argument"))
    usage;
  if String.equal !input_dir !output_dir then
    raise (Arg.Bad "input and output dirs can't be equal");
  Printf.printf "input=%s output=%s\n" !input_dir !output_dir;
  Printf.printf "has posts in input: %b\n"
    (Jgirvin_blog.contains_dir Posts !input_dir)
