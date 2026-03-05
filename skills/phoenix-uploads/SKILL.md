---
name: phoenix-uploads
description: Phoenix upload workflow guidance for validation, persistence, and static file serving. Use when implementing or debugging LiveView uploads, file validation, storage paths, or uploaded file delivery.
---

# Phoenix Uploads

## Rules

1. Default to manual uploads (no `auto_upload: true`) for form submission flows.
2. Add upload directories to `static_paths/0` before expecting served URLs.
3. Handle upload errors in templates and map them to user-facing messages.
4. Create destination directories with `File.mkdir_p!` before file copy/move.
5. Generate unique, sanitized filenames to avoid collisions and traversal issues.
6. Validate file type and size server-side; do not trust only client metadata.
7. Restart server after `static_paths/0` changes when testing locally.

## Use This Skill When

- Implementing or changing LiveView uploads.
- Adding static file serving for uploaded content.
- Troubleshooting upload validation, file persistence, or 404s on served files.

## Workflow

1. Configure `allow_upload/3` in `mount/3`.
2. Render file input, per-entry progress, and upload errors.
3. Consume entries in submit handler and persist resulting paths.
4. Verify `static_paths/0` and endpoint static config include the upload directory.

## References

- `../elixir/references/project-structure.md`

## Related Skills

- `phoenix-live-view`
- `testing`
