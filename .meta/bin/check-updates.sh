#!/bin/bash

set -uo pipefail

action=${1:-check}

return_code=0
applied=0
function check {
    repo=$1
    current=$2
    latest=$3

    if [[ "$latest" != "$current" ]]; then
      echo "* Update for $repo available $latest (current $current)"
      return_code=$((return_code+1))

      if [[ -f config.yaml && $action == "apply" ]]; then
        sed -i --follow-symlinks "s|\(\s*\)$repo: .*|\1$repo: $latest|g" config.yaml
        applied=$((applied+1))
      fi
    else
      echo "- $repo up to date ($current)"
    fi

}

curl_cfg=$(mktemp)
if [[ -n "${GH_BASIC_AUTH:-}" ]]; then
  echo "user = \"$GH_BASIC_AUTH\"" > "$curl_cfg"
fi
trap 'rv=$?; rm -f $curl_cfg; exit $rv' 0 2 3 15

for component in $(echo "$GITHUB_VERSIONS" | jq -cM 'to_entries | .[]'); do
  repo=$(echo "$component" | jq -r '.key')
  current=$(echo "$component" | jq -r '.value')

  latest=$(curl --config $curl_cfg -sf "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name' | sed 's/^v*//g')

  if [[ "$latest" == "null" ]]; then
    echo "! Cannot get latest version for $repo"
  else
    check "$repo" "$current" "$latest"
  fi
done

for component in $(echo "$PIP_VERSIONS" | jq -cM 'to_entries | .[]'); do
  repo=$(echo "$component" | jq -r '.key')
  current=$(echo "$component" | jq -r '.value')
  latest=$(curl -sf "https://pypi.org/pypi/${repo}/json" | jq -r '.info.version')

  check "$repo" "$current" "$latest"
done

# kubectl
current=$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion' | sed 's/^v*//g')
latest=$(curl -sf https://storage.googleapis.com/kubernetes-release/release/stable.txt | sed 's/^v*//g')
check "kubernetes/kubectl" "$current" "$latest"

# golang
if [[ -n $GOLANG_VERSION ]]; then
  current=$GOLANG_VERSION
  latest=$(curl -sf "https://go.dev/VERSION?m=text" | sed 's/^go//g')
  check "golang/go" "$current" "$latest"
fi

#awscli
current=$AWS_CLI_VERSION
latest=$(curl -sf "https://api.github.com/repos/aws/aws-cli/tags" | jq -r '[.[] | select( .name | test("^2")) | .name][0]')
check "awscli" "$current" "$latest"

op update

if [[ $applied -ne 0 ]]; then
  echo 'Rebuild your Docker image with new versions'
fi

exit $return_code
