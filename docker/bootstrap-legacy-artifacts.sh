#!/usr/bin/env bash
set -euo pipefail

M2_REPO="${HOME}/.m2/repository"
ORTH_REPO="https://github.com/threerings/orth.git"
ORTH_COMMIT="63ce1834dc65bdbee2be87c7a15ff3e70caf7ed6"
NENYA_REPO="https://github.com/threerings/nenya.git"
# Exact source state for Nenya 1.1: this is the parent of the commit that
# changed the project version from 1.1 to 1.2-SNAPSHOT.
NENYA_COMMIT="62c3c2c31a239aecb3028501a81bace2c8fee8f9"
WHIRLED_API_REPO="https://github.com/greyhavens/whirled-api.git"
WHIRLED_API_COMMIT="98c15e4d33b4340ce0e9b84b0aca1dd1a38f8508"
LWJGL_REPO="https://github.com/LWJGL/lwjgl.git"
LWJGL_26_COMMIT="67307a702399537465be003bc67d2cc2549ce61b"
LWJGL_26_URL="https://raw.githubusercontent.com/GeoJosh/geospace-repo/master/org/lwjgl/lwjgl/2.6/lwjgl-2.6.jar"
LWJGL_26_SHA1="02b8c8c496d5f858a3ba72793e419fb66ae624e8"

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

install_legacy_lwjgl() {
  local target_jar="${M2_REPO}/org/lwjgl/lwjgl/2.6/lwjgl-2.6.jar"
  if [[ -f "$target_jar" ]]; then
    return
  fi

  echo "Restoring org.lwjgl:lwjgl:2.6 from checksum-pinned archival Maven copy..."
  local workdir jar actual_sha1
  workdir="$(mktemp -d)"
  jar="$workdir/lwjgl-2.6.jar"

  curl -fsSL "$LWJGL_26_URL" -o "$jar"
  actual_sha1="$(sha1sum "$jar" | awk '{print $1}')"
  if [[ "$actual_sha1" != "$LWJGL_26_SHA1" ]]; then
    echo "LWJGL 2.6 checksum mismatch: expected ${LWJGL_26_SHA1}, got ${actual_sha1}" >&2
    rm -rf "$workdir"
    exit 3
  fi

  mvn -q install:install-file \
    -Dfile="$jar" \
    -DgroupId=org.lwjgl \
    -DartifactId=lwjgl \
    -Dversion=2.6 \
    -Dpackaging=jar \
    -DgeneratePom=true

  rm -rf "$workdir"
}

install_legacy_lwjgl_util() {
  local target_jar="${M2_REPO}/org/lwjgl/lwjgl_util/2.6/lwjgl_util-2.6.jar"
  local core_jar="${M2_REPO}/org/lwjgl/lwjgl/2.6/lwjgl-2.6.jar"
  if [[ -f "$target_jar" ]]; then
    return
  fi
  if [[ ! -f "$core_jar" ]]; then
    echo "LWJGL core must be installed before lwjgl_util: ${core_jar}" >&2
    exit 3
  fi

  echo "Rebuilding org.lwjgl:lwjgl_util:2.6 from the exact LWJGL 2.6 source tag..."
  local workdir util_jar
  workdir="$(mktemp -d)"
  util_jar="$workdir/lwjgl_util-2.6.jar"

  git clone -q --no-checkout "$LWJGL_REPO" "$workdir/lwjgl"
  git -C "$workdir/lwjgl" checkout -q "$LWJGL_26_COMMIT"
  mkdir -p "$workdir/classes"

  # Nenya 1.1 only consumes org.lwjgl.util.WaveData. Compile that exact class
  # from LWJGL's 2.6 tag against the checksum-pinned 2.6 core jar, avoiding the
  # obsolete full LWJGL native/generator build while preserving the exact API.
  javac -source 1.5 -target 1.5 \
    -cp "$core_jar" \
    -d "$workdir/classes" \
    "$workdir/lwjgl/src/java/org/lwjgl/util/WaveData.java"
  jar cf "$util_jar" -C "$workdir/classes" org/lwjgl/util/WaveData.class

  mvn -q install:install-file \
    -Dfile="$util_jar" \
    -DgroupId=org.lwjgl \
    -DartifactId=lwjgl_util \
    -Dversion=2.6 \
    -Dpackaging=jar \
    -DgeneratePom=true

  rm -rf "$workdir"
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

install_nenya() {
  local target_jar="${M2_REPO}/com/threerings/nenya/1.1/nenya-1.1.jar"
  if [[ -f "$target_jar" ]]; then
    return
  fi

  echo "Building com.threerings:nenya:1.1 from pinned exact release source..."
  local workdir pom
  workdir="$(mktemp -d)"
  pom="$workdir/nenya/pom.xml"

  git clone -q --no-checkout "$NENYA_REPO" "$workdir/nenya"
  git -C "$workdir/nenya" checkout -q "$NENYA_COMMIT"

  # Nenya 1.1 used Maven's old dynamic RELEASE plugin version. Modern Maven
  # rejects that marker while parsing the POM, before it can compile anything.
  # Pin the period-correct AntRun 1.6 release in the temporary checkout only.
  sed -i '/<artifactId>maven-antrun-plugin<\/artifactId>/{n;s#<version>RELEASE</version>#<version>1.6</version>#;}' "$pom"

  # That AntRun execution only builds test resources. AntRun 1.6 predates the
  # maven.antrun.skip parameter, but it explicitly supports target if/unless
  # attributes. Make this temporary bootstrap honor maven.test.skip so Maven can
  # install the main Nenya jar without invoking its obsolete Ant/Flex/native test
  # resource toolchain or downloading Maven Ant Tasks from a retired mirror.
  sed -i '/<artifactId>maven-antrun-plugin<\/artifactId>/,/<\/plugin>/ s#<target>#<target unless="maven.test.skip">#' "$pom"

  mvn -q -f "$pom" -Dmaven.test.skip=true install

  if [[ ! -f "$target_jar" ]]; then
    echo "Nenya source build completed without producing ${target_jar}" >&2
    exit 3
  fi

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

# Restore the exact binary coordinates Nenya needs before its old POM is resolved.
install_legacy_lwjgl
install_legacy_lwjgl_util

# The exact coordinates in MSOY's old POM disappeared with the original private
# Three Rings Maven repository. Vilya 1.4 is from the same legacy API generation
# and remains available from Central. Orth is rebuilt from its pinned 1.0 release
# source and installed under the old 0.9 coordinate expected by MSOY. Nenya 1.1
# is rebuilt from its exact pre-1.2-SNAPSHOT source state because Central contains
# Nenya 1.0 and 1.2 but no 1.1 artifact. The MSOY POM remains unchanged, so its
# explicit exclusions/version choices still control the rest of the graph.
install_alias_from_central com.threerings vilya 1.4 1.1
install_orth
install_nenya
install_whirled_code
