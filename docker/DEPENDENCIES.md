# Legacy Java dependency bootstrap

MSOY's historical Ant build does not make the top-level `compile` target depend on `mavendeps`.
On a clean checkout this leaves `dist/lib` without GWT, Guava, Samskivert and Three Rings jars and
causes large numbers of `cannot find symbol` / `package ... does not exist` errors.

The Docker entrypoint fixes the clean-container path by checking for representative runtime jars and
running `ant mavendeps` before the requested Ant build target when they are absent.

The container also installs `docker/maven-settings.xml`, which enables Maven Central and the legacy
Three Rings OOO repository over HTTPS:

`https://raw.githubusercontent.com/threerings/maven-repo/master/repository`

The Dockerfile runs the normal entrypoint build once while producing the image. This intentionally
turns dependency resolution or Java compilation errors into Docker image build failures instead of
publishing a GHCR image that only fails when a user starts it.
