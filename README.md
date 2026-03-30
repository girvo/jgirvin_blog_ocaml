# jgirvin.com SSG

## Core pipeline

- [x] Argument parsing (--input, --output)
- [x] Validate input dir contains posts/, pages/, templates/
- [x] Validate output dir exists
- [x] Check required templates exist (post.liquid, archive.liquid)
- [x] Read post .md files into memory
- [x] Parse YAML frontmatter from posts
- [x] Parse markdown body to HTML via cmarkit

## Pages

- [x] Define page_meta type (title, description — no author/date)
- [x] Read .liquid files from pages/
- [x] Extract frontmatter from page files

## Templating

- [x] Build liquid context from post data (post.title, post.slug, etc. + body)
- [x] Build liquid context from page data (page.title, page.description)
- [x] Build site-level context (site title, post list for nav/archive) **NEARLY DONE**
- [x] Render posts: HTML injected as {{ body | raw }} into templates/post.liquid
- [x] Render pages: read .liquid file, render via render_text with page + site context
- [x] Set template_directory so {% include %} resolves partials from templates/

## Partials

- [ ] partials/header.liquid (doctype, <head>, <title> from page.title, nav)
- [ ] partials/footer.liquid

## Archive / Index

- [x] Render templates/archive.liquid with full post list as context
- [x] Sort posts by date (newest first)
- [x] Filter out drafts

## Output

- [x] Create output directory structure
- [x] Write rendered posts (slug-based paths, e.g. /hello-world/index.html)
- [x] Write rendered pages (e.g. /about/index.html)
- [x] Copy static assets (CSS, images, etc.) to output

## Error handling

- [ ] Surface missing template errors clearly
- [ ] Surface frontmatter parse errors per-file (already returning Result)
- [ ] Handle liquid render errors (use error_policy setting)

## Later

- [ ] RSS/Atom feed
- [ ] Tags/categories
- [ ] Sitemap
- [ ] Dev server with livereload
- [ ] Pagination
