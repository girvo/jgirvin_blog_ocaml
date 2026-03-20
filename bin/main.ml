let contains_posts_dir path =
  path
  |> Sys.readdir
  |> Array.exists (String.equal "posts")

let usage_message = "jgirvin_blog <path>"
let path = ref ""

let () =
  Arg.parse [] (fun p -> path := p) usage_message;
  let path = if !path = "" then "." else !path in
  Printf.printf "%b\n" (contains_posts_dir path)
