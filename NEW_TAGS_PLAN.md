# Adding Tags to jgirvin_blog

## Overview

Add a tagging system to the static site generator. Tags are URL-safe, single-word strings defined in post frontmatter. Each tag gets its own archive page, and a tags index page lists all tags. Tags are displayed on post pages next to the date, right-justified.

## Frontmatter Format

```yaml
---
title: Hello, world!
slug: hello-world
author: Josh Girvin
date: 2026-04-01
description: ...
tags: [blog, music, 2026]
---
```

- Tags are optional (default to empty list)
- Maximum 3 tags per post — enforced by the SSG at parse time

## Generated URL Structure

```
/tags/              -> index page listing all tags with post counts
/tags/music/        -> archive-style list of all posts tagged "music"
/tags/2026/         -> archive-style list of all posts tagged "2026"
```

Each tag page is an `index.html` inside the tag's directory, matching the existing pattern used by posts and pages.

---

## Implementation Steps

### 1. Update `post_meta` type

**Files:** `lib/jgirvin_blog.mli` and `lib/jgirvin_blog.ml`

Add `tags` field to `post_meta`:

```ocaml
type post_meta = {
  title : string;
  slug : string;
  author : string;
  date : string;
  draft : bool; [@default false]
  description : string option;
  tags : string list; [@default []]
}
```

The `[@default []]` annotation means posts without tags will parse fine with an empty list. The `ppx_deriving_yaml` and `skip_unknown` setup already handles optional fields.

### 2. Validate tag count in `parse_post`

**File:** `lib/jgirvin_blog.ml`

After successfully parsing the YAML frontmatter in `parse_post`, add a check:

```
if the number of tags on the post > 3 then
  return Error with a message like "post 'slug' has N tags (max 3)"
else
  return Ok with the post
```

### 3. Add `collect_tags` helper

**File:** `lib/jgirvin_blog.ml` (and expose in `.mli`)

```ocaml
val collect_tags : post list -> (string * post list) list
```

This function:
- Takes the full list of published posts
- Groups them by tag (a post with 3 tags appears in 3 groups)
- Sorts groups alphabetically by tag name
- Each group's posts are already sorted by date (they come in sorted from the build pipeline)

Implementation approach:

```
collect_tags(posts):
  create an empty hashtable (key: tag string, value: list of posts)

  for each post in posts:
    for each tag in post.meta.tags:
      get current list for this tag (or empty list if not found)
      prepend post to that list
      store updated list back in hashtable

  convert hashtable to a list of (tag, posts) pairs
  reverse each posts list (because we prepended earlier)
  sort the list of pairs alphabetically by tag name
  return the sorted list
```

Note: reversing is needed because posts are iterated in date-descending order and prepended, so reversing restores newest-first.

### 4. Pass tags to post template context

**File:** `bin/main.ml`

In the post rendering loop (around line 223), add tags to the context:

```
add "tags" to the context, where the value is a list of objects,
each object having:
  - "name": the tag string
  - "link": "/tags/{tag}/"
```

Also add tags to `post_items` (around line 260) so they're available in archive/feed templates:

```
same structure as above: for each tag, create an object with
"name" and "link" fields, and add this list to the post object
under the "tags" key
```

### 5. Generate per-tag archive pages

**File:** `bin/main.ml`

Add a new function `render_tag_pages` (or inline it in the build pipeline). For each tag from `collect_tags`:

1. Create directory: `{output}/tags/{tag}/`
2. Reuse `archive.liquid` as the template
3. Build context with:
   - `title` = the tag name (e.g. "music")
   - `all_posts` = the filtered post items for that tag (same Object format as `post_items`)
   - Base context (site_title, site_url)
4. Render to `{output}/tags/{tag}/index.html`

You'll also need to create the parent `{output}/tags/` directory first.

### 6. Generate tags index page

**File:** `bin/main.ml`

New function `render_tags_index`:

1. Needs a new template: `tags.liquid`
2. Context:
   - `title` = "Tags"
   - `all_tags` = List of Objects, each with:
     - `name` (String) — the tag
     - `link` (String) — e.g. `/tags/music/`
     - `count` (String) — number of posts with that tag (Liquid doesn't have int type in liquid_ml, use string)
   - Base context
3. Output to `{output}/tags/index.html`

Add `tags.liquid` to the required templates list in `check_required_templates` (`lib/jgirvin_blog.ml`, around line 72-90).

### 7. Update sitemap and RSS feed

**Sitemap** (`bin/main.ml` in `render_sitemap`):

Add a new `all_tags` list to the sitemap context and update `sitemap.xml.liquid` to iterate over it. This should include both `/tags/` and each `/tags/{tag}/`.

**RSS feed** (`feed.xml.liquid` template only — no OCaml changes needed):

Don't create per-tag feeds. Instead, add `<category>` elements to each `<item>` in the existing feed using the `post.tags` data already being passed via `post_items` (from step 4):

```xml
<item>
  <title>{{ post.title }}</title>
  ...
  {% for tag in post.tags %}
  <category>{{ tag.name }}</category>
  {% endfor %}
</item>
```

This is standard RSS 2.0 and feed readers that support categories will pick them up automatically.

### 8. Update build pipeline ordering

**File:** `bin/main.ml`

In the main `let () = ...` block (line 190+), add the tag rendering steps after the archive rendering:

```
Rendering archive...
Rendering tag pages...      <-- NEW
Rendering tags index...     <-- NEW
Rendering RSS feed...
```

---

## Templates to Create/Update

### Update: `post.liquid` (in your blog repo, not the SSG)

Replace the `<header>` section to show tags right-justified on the date line:

```liquid
<header>
  <div style="display:flex;justify-content:space-between;align-items:baseline">
    <time datetime="{{ date }}">{{ date | date: "%-d %B %Y" }}</time>
    {% if tags.size > 0 %}
      <span class="tags">
        {% for tag in tags %}
          <a href="{{ tag.link }}">{{ tag.name }}</a>{% unless forloop.last %} | {% endunless %}
        {% endfor %}
      </span>
    {% endif %}
  </div>
  <h1>{{ title }}</h1>
</header>
```

This gives:
```
1 April 2026                    blog | music | 2026
Hello, World!
```

You may want to style `.tags` and `.tags a` in your CSS to match the date's muted appearance (e.g. same color/size as `<time>`).

### New: `tags.liquid` (in both example/ and blog repo)

```liquid
{% include "partials/header" %}

<h1>Tags</h1>
{% for tag in all_tags %}
  <div>
    <a href="{{ tag.link }}">{{ tag.name }}</a> ({{ tag.count }})
  </div>
{% endfor %}

{% include "partials/footer" %}
```

### No changes needed: `archive.liquid`

The archive template already uses `{{ title }}` for its heading and iterates `all_posts`. When reused for per-tag pages, `title` will be set to the tag name and `all_posts` will be the filtered set. It just works.

### Update: `sitemap.xml.liquid`

Add a section for tag pages (both the index and individual tag pages):

```liquid
<url>
  <loc>{{ site_url }}/tags/</loc>
</url>
{% for tag in all_tags %}
<url>
  <loc>{{ site_url }}{{ tag.link }}</loc>
</url>
{% endfor %}
```

### Update: `feed.xml.liquid`

Add `<category>` elements inside each `<item>` block. No new feeds — just enrich the existing one:

```liquid
{% for tag in post.tags %}
<category>{{ tag.name }}</category>
{% endfor %}
```

---

## Tests to Add

**File:** `test/test_jgirvin_blog.ml`

1. **Parse post with tags** — frontmatter with `tags: [a, b, c]` parses correctly, `meta.tags = ["a"; "b"; "c"]`
2. **Parse post without tags** — existing frontmatter still works, `meta.tags = []`
3. **Reject >3 tags** — frontmatter with `tags: [a, b, c, d]` returns `Error`
4. **`collect_tags` grouping** — given posts with overlapping tags, verify correct grouping and alphabetical sort
5. **`collect_tags` empty** — posts with no tags return empty list

---

## Example Post Update

Update `example/posts/hello-world.md` frontmatter:

```yaml
---
title: Hello, world!
slug: hello-world
author: Someone
date: 2026-03-06T15:09:00
description: This is my first blog post!
tags: [blog, test]
---
```

Also add `example/templates/tags.liquid` with the template content from above.

---

## Verification Checklist

- [ ] `dune build` compiles without errors
- [ ] `dune test` passes all new and existing tests
- [ ] Run SSG against example site: `dune exec jgirvin_blog -- --input example --output build`
- [ ] `build/tags/index.html` exists and lists all tags
- [ ] `build/tags/blog/index.html` exists and lists correct posts
- [ ] Post pages show tags next to the date
- [ ] Tag links navigate to correct per-tag archive pages
- [ ] Post with >3 tags is rejected with clear error message
- [ ] Post with 0 tags renders without tag display
- [ ] Sitemap includes tag pages