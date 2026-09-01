#!/usr/bin/env bash
set -euo pipefail

M2_REPO="${HOME}/.m2/repository"
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

install_whirled_code() {
  local target_jar="${M2_REPO}/com/threerings/whirled-code/1.1-SNAPSHOT/whirled-code-1.1-SNAPSHOT.jar"
  if [[ -f "$target_jar" ]]; then
    return
  fi

  echo "Building com.threerings:whirled-code:1.1-SNAPSHOT from pinned Grey Havens source..."
  local workdir
  workdir="$(mktemp -d)"
  trap 'rm -rf "$workdir"' RETURN

  git clone -q --no-checkout "$WHIRLED_API_REPO" "$workdir/whirled-api"
  git -C "$workdir/whirled-api" checkout -q "$WHIRLED_API_COMMIT"
  mvn -q -f "$workdir/whirled-api/pom.xml" -DskipTests -pl core -am install

  if [[ ! -f "$target_jar" ]]; then
    echo "Whirled API build completed without producing ${target_jar}" >&2
    exit 3
  fi

  rm -rf "$workdir"
  trap - RETURN
}

# The exact coordinates in MSOY's old POM disappeared with the original private
# Three Rings Maven repository. These nearby releases are from the same legacy
# API generation and are used only to restore the missing binary coordinates;
# the MSOY POM remains unchanged and its explicit exclusions/version choices
# continue to control the rest of the dependency graph.
install_alias_from_central com.threerings vilya 1.4 1.1
install_alias_from_central com.threerings orth 1.0 0.9
install_whirled_code
