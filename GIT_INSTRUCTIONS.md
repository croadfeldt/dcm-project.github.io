# How to apply this content update

## Prerequisites
- Close PR #7 (this supersedes it)
- You have push access to dcm-project/dcm-project.github.io

## Steps

```bash
# 1. Clone the repo
git clone git@github.com:dcm-project/dcm-project.github.io.git
cd dcm-project.github.io

# 2. Create branch
git checkout -b content-update

# 3. Remove old content (preserve everything else)
rm -rf content/ static/
git add -A
git commit -m "Remove old content for replacement"

# 4. Copy new content from the package
cp -r /path/to/website-content/content .
cp -r /path/to/website-content/static .

# 5. Do NOT commit PR_DESCRIPTION.md or GIT_INSTRUCTIONS.md
# (they're for your reference only)

# 6. Add and commit
git add -A
git commit -m "Update content: fixed, deduplicated architecture (55 data model docs, 15 specs, 4 OpenAPI)

Addresses all PR #7 review comments:
- Eliminated duplicate data-model directories
- Fixed all broken cross-references
- Removed 116 duplicate files
- Updated provider count (12), policy count (8), classification enum (8)
- Synced all OpenAPI YAMLs with canonical schemas"

# 7. Push and open PR
git push origin content-update
# Use PR_DESCRIPTION.md as the PR body
```
