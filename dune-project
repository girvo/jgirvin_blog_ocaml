(lang dune 3.21)

(name jgirvin_blog)

(generate_opam_files true)

(source
 (github girvo/jgirvin_blog_ocaml))

(authors "Josh Girvin <josh@jgirvin.com>")

(maintainers "Josh Girvin <josh@jgirvin.com")

(license MIT)

(documentation https://url/to/documentation)

(package
 (name jgirvin_blog)
 (synopsis "A Liquid-based SSG for blogging")
 (description "Learning OCaml by building a blogging system")
 (depends
  ocaml
  liquid_ml
  yaml
  frontmatter_extractor
  ppx_deriving_yaml
  cmarkit
  hilite
  (alcotest :with-test)
  (ocamlformat :with-dev-setup))
 (tags
  ("ssg" "blog")))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
