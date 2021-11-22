#!/bin/bash

set -euo pipefail

return_code=0

for component in $(echo $VERSIONS | jq -cM 'to_entries | .[]'); do
  repo=$(echo $component | jq -r '.key')
  current=$(echo $component | jq -r '.value')
  latest=$(curl -s "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name')

  if [[ "$latest" != "$current" ]]; then
    echo "* Update for $repo available $latest (current $current)"

    return_code=1
  else
    echo "- $repo up to date ($current)"
  fi
done

exit $return_code
