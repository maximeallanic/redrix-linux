#!/usr/bin/env bash
# Prepares a release: builds the tarball that the one-line installer downloads and pins its sha256 in install.sh.
#
#   scripts/release.sh 0.2.0               1. sets the version in lib/common.sh and install.sh,
#                                           2. builds dist/redrix-linux-0.2.0.tar.gz from that tree,
#                                           3. writes its sha256 into install.sh (RELEASE_SHA256) and commits the
#                                              three changes as "chore(release): 0.2.0". Then tag and push.
#   scripts/release.sh --build-only 0.2.0  CI: rebuilds the tarball from the tag and checks it matches the pin.
#
# The tarball is reproducible (git archive, sorted entries, fixed dates, owners and modes, gzip -n) and is built with
# the RELEASE_SHA256 value of install.sh blanked, so its hash does not depend on the pin it is written into: the CI
# build of the tag gives the same bytes as the build made here.
set -euo pipefail
export LC_ALL=C
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

BUILD_ONLY=0
if [[ ${1:-} == --build-only ]]; then BUILD_ONLY=1; shift; fi
VERSION=${1:?usage: scripts/release.sh [--build-only] X.Y.Z}
[[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must be X.Y.Z" >&2; exit 2; }
NAME=redrix-linux-$VERSION
mkdir -p dist

# archive TREE-ISH: the tree as $NAME/, with the RELEASE_SHA256 value in install.sh emptied, gzip without timestamp.
archive() {
    local ref=$1 work
    work=$(mktemp -d "$ROOT/dist/.build.XXXXXX")
    git archive --format=tar --prefix="$NAME/" "$ref" | tar -x -C "$work"
    sed -i "s/^RELEASE_SHA256=.*/RELEASE_SHA256=''/" "$work/$NAME/install.sh"
    tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner --mode='u+rwX,go+rX,go-w' -C "$work" -cf - "$NAME" | gzip -n -9 >"dist/$NAME.tar.gz"
    rm -rf -- "$work"
    (cd dist && sha256sum "$NAME.tar.gz" >"$NAME.tar.gz.sha256")
}

if ((BUILD_ONLY)); then
    archive HEAD
    pinned=$(sed -n "s/^RELEASE_SHA256='\(.*\)'$/\1/p" install.sh)
    built=$(cut -d' ' -f1 "dist/$NAME.tar.gz.sha256")
    [[ $(sed -n 's/^RELEASE_VERSION=//p' install.sh) == "$VERSION" ]] || { echo "install.sh pins another version" >&2; exit 1; }
    [[ $pinned == "$built" ]] || { echo "install.sh pins $pinned, the tag builds $built" >&2; exit 1; }
    awk -v h="## $VERSION" '$0 == h {on = 1; next} /^## / {on = 0} on' CHANGELOG.md >dist/notes.md
    [[ -s dist/notes.md ]] || { echo "CHANGELOG.md has no '## $VERSION' section" >&2; exit 1; }
    echo "dist/$NAME.tar.gz matches the pin ($built)"
    exit 0
fi

[[ -z $(git status --porcelain) ]] || { echo "commit or stash your changes first" >&2; exit 1; }
grep -qx "## $VERSION" CHANGELOG.md || { echo "CHANGELOG.md has no '## $VERSION' section" >&2; exit 1; }
sed -i "s/^REDRIX_VERSION=.*/REDRIX_VERSION=$VERSION/" lib/common.sh
sed -i "s/^RELEASE_VERSION=.*/RELEASE_VERSION=$VERSION/" install.sh
git add lib/common.sh install.sh
# The tarball is the staged tree (version set, pin blanked by archive): the commit below differs only by the pin.
archive "$(git write-tree)"
sha=$(cut -d' ' -f1 "dist/$NAME.tar.gz.sha256")
sed -i "s/^RELEASE_SHA256=.*/RELEASE_SHA256='$sha'/" install.sh
git add install.sh
git commit -q -m "chore(release): $VERSION"
echo "Pinned $NAME.tar.gz ($sha) in install.sh and committed. Then:"
echo "    git tag -s v$VERSION -m 'redrix-linux $VERSION' && git push origin main v$VERSION"
