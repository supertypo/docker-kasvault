ARCHES="linux/amd64 linux/arm64"

REPO_URL="https://github.com/coderofstuff/kasvault"
DOCKER_REPO="supertypo/kasvault"
BUILD_DIR="$(dirname $0)"
PUSH=$1
VERSION=$2
TAG=${3:-main}
REPO_URL=${4:-$REPO_URL}
REPO_DIR="$BUILD_DIR/.work/$(echo $REPO_URL | sed -E 's/[^a-zA-Z0-9]+/_/g')"

set -e

if [ ! -d "$REPO_DIR" ]; then
  git clone "$REPO_URL" "$REPO_DIR"
fi

echo "============================================================="
echo " Pulling $REPO_URL"
echo "============================================================="
(cd "$REPO_DIR" && git fetch && git checkout $TAG && git reset --hard origin/$TAG)

tag=$(cd "$REPO_DIR" && git log -n1 --format="%cs.%h")

docker=docker
id -nG $USER | grep -qw docker || docker="sudo $docker"

plain_build() {
  echo
  echo "============================================================="
  echo " Running current arch build"
  echo "============================================================="

  $docker build --pull \
    --build-arg REPO_DIR="$REPO_DIR" \
    --tag ${DOCKER_REPO}:$tag "$BUILD_DIR"

  if [ -n "$VERSION" ]; then
     $docker tag $DOCKER_REPO:$tag $DOCKER_REPO:$VERSION
     echo Tagged $DOCKER_REPO:$VERSION
     $docker tag $DOCKER_REPO:$tag $DOCKER_REPO:latest
     echo Tagged $DOCKER_REPO:latest
   else
     $docker tag $DOCKER_REPO:$tag $DOCKER_REPO:unstable
     echo Tagged $DOCKER_REPO:unstable
  fi

  if [ "$PUSH" = "push" ]; then
    $docker push $DOCKER_REPO:$tag
    if [ -n "$VERSION" ]; then
       $docker push $DOCKER_REPO:$VERSION
       $docker push $DOCKER_REPO:latest
     else
       $docker push $DOCKER_REPO:unstable
    fi
  fi
  echo "============================================================="
  echo " Completed current arch build"
  echo "============================================================="
}

multi_arch_build() {
  echo
  echo "============================================================="
  echo " Running multi arch build"
  echo "============================================================="
  dockerRepoArgs=
  if [ "$PUSH" = "push" ]; then
    dockerRepoArgs="$dockerRepoArgs --push"
  fi
  if [ -n "$VERSION" ]; then
    dockerRepoArgs="$dockerRepoArgs --tag $DOCKER_REPO:$VERSION"
    dockerRepoArgs="$dockerRepoArgs --tag $DOCKER_REPO:latest"
  else
    dockerRepoArgs="$dockerRepoArgs --tag $DOCKER_REPO:unstable"
  fi
  $docker buildx build --pull --platform=$(echo $ARCHES | sed 's/ /,/g') $dockerRepoArgs \
    --build-arg REPO_DIR="$REPO_DIR" \
    --tag $DOCKER_REPO:$tag "$BUILD_DIR"
  echo "============================================================="
  echo " Completed multi arch build"
  echo "============================================================="
}

if [ "$PUSH" = "push" ]; then
  echo
  echo "============================================================="
  echo " Setup multi arch build ($ARCHES)"
  echo "============================================================="
  if $docker buildx create --name=mybuilder --append --node=mybuilder0 --platform=$(echo $ARCHES | sed 's/ /,/g') --bootstrap --use 1>/dev/null 2>&1; then
    echo "SUCCESS - doing multi arch build"
    multi_arch_build
  else
    echo "FAILED - building on current arch"
    plain_build
  fi
else
  plain_build
fi

