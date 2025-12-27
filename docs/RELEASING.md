# Releasing

Demark uses SemVer tags (`1.0.1`) and GitHub Releases.

## Release Checklist

1. Update `CHANGELOG.md` (move “Unreleased” to a date, add notes).
2. Run the same checks as CI:
   - `swift build -v`
   - `swift test -v`
   - `./scripts/lint.sh`
   - `(cd Example && swift build -v)`
3. Commit release prep changes.
4. Create an annotated tag:
   - `git tag -a 1.0.1 -m "Release 1.0.1"`
5. Push `main` + tags:
   - `git push origin main --tags`
6. Create a GitHub Release:
   - `gh release create 1.0.1 --title "1.0.1" --notes-file /tmp/demark-1.0.1.md`

## Notes

- CI runs on branch pushes/PRs and tags (see `.github/workflows/ci.yml`).
