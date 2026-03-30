# jgirvin.com SSG

A static site generator written in OCaml. Uses Liquid templates, Markdown posts with YAML frontmatter, and outputs HTML.

## Usage

```
jgirvin_blog --input <dir> --output <dir>
```

- `--input` - Path to the input directory (default: `.`)
- `--output` - Path to the output directory (default: `build`). Must already exist.

## Input directory structure

```
input/
  posts/        .md files with YAML frontmatter
  pages/        .liquid files with YAML frontmatter
  templates/    Liquid templates and partials
  assets/       Static files (CSS, images, etc.), copied as-is
```

## Required templates

- `templates/post.liquid`
- `templates/archive.liquid`
- `templates/feed.xml.liquid`
- `templates/sitemap.xml.liquid`
- `pages/index.liquid`

## Post frontmatter

```yaml
---
title: Hello World
slug: hello-world
author: Josh
date: 2026-03-30
draft: false        # optional, defaults to false
description: ...    # optional
---
```

## Page frontmatter

```yaml
---
title: About
draft: false        # optional, defaults to false
description: ...    # optional
---
```

## Output

Posts are written to `<output>/<slug>/index.html`. Pages are written to `<output>/<page-name>/index.html`, except `index.liquid` which writes to `<output>/index.html`. The archive goes to `<output>/archive/index.html`. RSS feed and sitemap are written to `<output>/feed.xml` and `<output>/sitemap.xml`.