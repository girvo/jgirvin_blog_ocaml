let has_posts path =
  path
  |> Sys.readdir
  |> Array.exists (String.equal "posts")

let usage_message = "jgirvin_blog <path>"
let path = ref ""
let store_path arg =
  path := arg

let run path =
  Printf.printf "%b" (has_posts path)

let () =
  Arg.parse [] store_path usage_message;
  Printf.printf "%b\n" (has_posts !path)
