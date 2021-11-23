#!/bin/bash

set -euo pipefail

return_code=0
function check {
    repo=$1
    current=$2
    latest=$3

    if [[ "$latest" != "$current" ]]; then
      echo "* Update for $repo available $latest (current $current)"
      return_code=$((return_code+1))
    else
      echo "- $repo up to date ($current)"
    fi
}

for component in $(echo "$VERSIONS" | jq -cM 'to_entries | .[]'); do
  repo=$(echo "$component" | jq -r '.key')
  current=$(echo "$component" | jq -r '.value')
  latest=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name')

  check "$repo" "$current" "$latest"
done

# kubectl
current=$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')
latest=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
check "kubernetes/kubectl" "$current" "$latest"

# golang
if [[ -n $GOLANG_VERSION ]]; then
  current="go$GOLANG_VERSION"
  latest=$(curl -s "https://go.dev/VERSION?m=text")
  check "golang/go" "$current" "$latest"
fi

op update

exit $return_code
