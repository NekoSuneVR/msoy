#!/usr/bin/env bash
set -euo pipefail

M2_REPO="${HOME}/.m2/repository"
ORTH_REPO="https://github.com/threerings/orth.git"
ORTH_COMMIT="63ce1834dc65bdbee2be87c7a15ff3e70caf7ed6"
WHIRLED_API_REPO="https://github.com/greyhavens/whirled-api.git"
WHIRLED_API_COMMIT="98c15e4d33b4340ce0e9b84b0aca1dd1a38f8508"

install_alias_from_central() {
  local group_id="$1"
  local artifact_id="$2"
  local source_version="$3"
  local target_version="$4"
  local group_path="${group_id//./\/}"
  local target_jar="${M2_REPO}/${group_path}/${artifact_id}/${target_version}/${artifact_id}-${target_version}.jar"

  if [[ -f "$target_jar" ]]; then
    return
  fi

  echo "Bootstrapping ${group_id}:${artifact_id}:${target_version} from compatible ${source_version} release..."
  mvn -q -Dtransitive=false dependency:get \
    -Dartifact="${group_id}:${artifact_id}:${source_version}"

  local source_jar="${M2_REPO}/${group_path}/${artifact_id}/${source_version}/${artifact_id}-${source_version}.jar"
  if [[ ! -f "$source_jar" ]]; then
    echo "Resolved artifact is missing: ${source_jar}" >&2
    exit 3
  fi

  mvn -q install:install-file \
    -Dfile="$source_jar" \
    -DgroupId="$group_id" \
    -DartifactId="$artifact_id" \
    -Dversion="$target_version" \
    -Dpackaging=jar \
    -DgeneratePom=true
}

install_orth() {
  local target_jar="${M2_REPO}/com/threerings/orth/0.9/orth-0.9.jar"
  if [[ -f "$target_jar" ]]; then
    return
  fi

  echo "Building com.threerings:orth from pinned 1.0 release source for the legacy 0.9 coordinate..."
  local workdir
  workdir="$(mktemp -d)"

  git clone -q --no-checkout "$ORTH_REPO" "$workdir/orth"
  git -C "$workdir/orth" checkout -q "$ORTH_COMMIT"
  mvn -q -f "$workdir/orth/pom.xml" -DskipTests install

  local source_jar="${M2_REPO}/com/threerings/orth/1.0/orth-1.0.jar"
  if [[ ! -f "$source_jar" ]]; then
    echo "Orth source build completed without producing ${source_jar}" >&2
    exit 3
  fi

  mvn -q install:install-file \
    -Dfile="$source_jar" \
    -DgroupId=com.threerings \
    -DartifactId=orth \
    -Dversion=0.9 \
    -Dpackaging=jar \
    -DgeneratePom=true

  rm -rf "$workdir"
}

install_whirled_code() {
  local target_jar="${M2_REPO}/com/threerings/whirled-code/1.1-SNAPSHOT/whirled-code-1.1-SNAPSHOT.jar"
  if [[ -f "$target_jar" ]]; then
    return
  fi

  echo "Building com.threerings:whirled-code:1.1-SNAPSHOT from pinned Grey Havens Java API source..."
  local workdir
  workdir="$(mktemp -d)"

  git clone -q --no-checkout "$WHIRLED_API_REPO" "$workdir/whirled-api"
  git -C "$workdir/whirled-api" checkout -q "$WHIRLED_API_COMMIT"

  # Build the Java module directly. Building from the repository root makes Maven
  # parse the unrelated aslib/thanelib Flex modules, which require retired
  # FlexMojos, Adobe SWCs and scala-tools repositories. The core POM inherits the
  # local parent via ../pom.xml but does not enter that obsolete reactor.
  mvn -q -f "$workdir/whirled-api/core/pom.xml" -DskipTests install

  if [[ ! -f "$target_jar" ]]; then
    echo "Whirled Java API build completed without producing ${target_jar}" >&2
    exit 3
  fi

  rm -rf "$workdir"
}

# The exact coordinates in MSOY's old POM disappeared with the original private
# Three Rings Maven repository. Vilya 1.4 is from the same legacy API generation
# and remains available from Central. Orth is rebuilt from its pinned 1.0 release
# source and installed under the old 0.9 coordinate expected by MSOY. The MSOY
# POM remains unchanged, so its explicit exclusions/version choices still control
# the rest of the dependency graph.
install_alias_from_central com.threerings vilya 1.4 1.1
install_orth
install_whirled_code
