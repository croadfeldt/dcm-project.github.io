# dcm-project.github.io

Official DCM project documentation website - includes enhancements, guides, blog
posts, and demo recordings.

**Live site:** https://dcm-project.github.io/

## Development

Requires [Hugo extended](https://gohugo.io/installation/).

```bash
# Development server (http://localhost:1313)
make serve
```

> **Tip:** Use `hugo server --ignoreCache` if remote content doesn't refresh.

```bash
# Production build
make build
```

## Enhancement

Enhancements are linked directly to the [DCM Enhancements
Repository](https://github.com/dcm-project/enhancements).<br>
No file syncing required, content is fetched at build time.

Edit `content/docs/enhancements/_index.md` to add new enhancement links when
they are created.
