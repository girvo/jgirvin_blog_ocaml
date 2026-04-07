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
      Unix.mkdir (Filename.concat dir (dir_to_string Assets)) 0o755;
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

let post_testable = testable pp_post equal_post

let test_parse_post_no_frontmatter () =
  check
    (result post_testable string)
    "returns error" (Error "No frontmatter found")
    (parse_post ~file:"ignored" "blah")

let test_parse_post_broken_frontmatter () =
  match parse_post ~file:"ignored" "---\na\n---\n" with
  | Error _ -> ()
  | Ok _ -> Alcotest.fail "expected Error, got Ok"

let test_parse_post_missing_required () =
  match parse_post ~file:"ignored" "---\ntitle: testing\n---\n" with
  | Error _ -> ()
  | Ok _ -> Alcotest.fail "expected Error, got Ok"

let valid_post =
  {|
---
title: Test
slug: my-cool-test
author: Josh Girvin
date: 2026-03-28
---
# This is my body content! Nice
|}

let test_parse_post_valid () =
  check
    (result post_testable string)
    "returns valid post"
    (Ok
       {
         file = "test.md";
         body = "\n# This is my body content! Nice\n";
         meta =
           {
             title = "Test";
             slug = "my-cool-test";
             author = "Josh Girvin";
             date = "2026-03-28";
             draft = false;
             description = None;
             tags = [];
           };
       })
    (parse_post ~file:"test.md" valid_post)

let page_testable = testable pp_page equal_page

let valid_page = {|
---
title: Test Page
---
<h1>Hello, world!</h1>
|}

let test_parse_page_valid () =
  check
    (result page_testable string)
    "returns valid page"
    (Ok
       {
         file = "test.md";
         body = "\n<h1>Hello, world!</h1>\n";
         meta = { title = "Test Page"; draft = false; description = None };
       })
    (parse_page ~file:"test.md" valid_page)

let test_page_output_path_normal () =
  check string "returns normal page path" "output/my-page"
    (page_output_path "output"
       {
         file = "input/pages/my-page.liquid";
         body = "";
         meta = { title = "Ignore"; draft = false; description = None };
       })

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
      ( "parsing",
        [
          test_case "no frontmatter" `Quick test_parse_post_no_frontmatter;
          test_case "broken frontmatter" `Quick
            test_parse_post_broken_frontmatter;
          test_case "missing required fields" `Quick
            test_parse_post_missing_required;
          test_case "valid post" `Quick test_parse_post_valid;
          test_case "valid page" `Quick test_parse_page_valid;
          test_case "normal page path" `Quick test_page_output_path_normal;
        ] );
    ]
