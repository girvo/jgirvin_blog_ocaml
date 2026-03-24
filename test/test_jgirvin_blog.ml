open Alcotest
open Jgirvin_blog

let with_temp_dir f =
  let dir = Filename.temp_dir "jgirvin_blog_test_" "" in
  Fun.protect
    ~finally:(fun () ->
      (try Unix.rmdir (Filename.concat dir (dir_to_string Posts)) with _ -> ());
      try Unix.rmdir dir with _ -> ())
    (fun () -> f dir)

let test_contains_posts_dir_true () =
  with_temp_dir (fun dir ->
      Unix.mkdir (Filename.concat dir (dir_to_string Posts)) 0o755;
      check bool "contains posts" true (contains_dir Posts dir))

let test_contains_posts_dir_false () =
  with_temp_dir (fun dir ->
      check bool "no posts" false (contains_dir Posts dir))

let test_contains_all_dirs_true () =
  with_temp_dir (fun dir ->
      Unix.mkdir (Filename.concat dir (dir_to_string Posts)) 0o755;
      Unix.mkdir (Filename.concat dir (dir_to_string Pages)) 0o755;
      Unix.mkdir (Filename.concat dir (dir_to_string Templates)) 0o755;
      check bool "contains all needed folders" true (is_valid_input_dir dir))

let test_contains_all_dirs_false () =
  with_temp_dir (fun dir ->
      Unix.mkdir (Filename.concat dir (dir_to_string Posts)) 0o755;
      check bool "not all needed folders" false (is_valid_input_dir dir))

let test_output_dir_exists_true () =
  with_temp_dir (fun dir ->
      let output_dir = Filename.concat dir "output" in
      Unix.mkdir output_dir 0o755;
      check bool "output exists" true (is_valid_output_dir output_dir))

let test_output_dir_exists_false () =
  check bool "output doesn't exist" false
    (is_valid_output_dir "this_is_a_folder_that_wont_exist")

let () =
  run "jgirvin_blog"
    [
      ( "paths",
        [
          test_case "contains posts dir" `Quick test_contains_posts_dir_true;
          test_case "no posts dir" `Quick test_contains_posts_dir_false;
          test_case "contains all dirs" `Quick test_contains_all_dirs_true;
          test_case "does not contain all dirs" `Quick
            test_contains_all_dirs_false;
          test_case "contains valid output dir" `Quick
            test_output_dir_exists_true;
          test_case "does not contain output dir" `Quick
            test_output_dir_exists_false;
        ] );
    ]
