open Jgirvin_blog
open Alcotest

let test_my_thing () =
  check bool "is true" false true

let () =
  run "jgirvin_blog" [
    "rgr", [
      test_case "fake test" `Quick test_my_thing
    ]
  ]
