#!/bin/bash

set -e

# Where the list should get saved
version_list=${1}

# The correct base directory where the component resides
# Depending on the commodore compilation method it's not always the same.
base_dir=${2}

function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

cd "${base_dir}"

revs=$(git rev-list --tags)

# We get the last 20 component versions
git_list="$(git describe --abbrev=0 --tags --always $revs | grep  "v.*" | sort -uVr | head -n 20 )"

rm -f "$version_list"

while read -r version rest
do
  hash=$(git rev-list -n 1 "$version")
  eval "$(git show "$hash":class/defaults.yml | parse_yaml )"
  echo "${version}-${parameters_appcat_images_appcat_tag}" >> "$version_list"
done <<< "$git_list"

# Now we get the last 5 appcat version, as the component can change without appcat changes
filtered_versions=$(cat "$version_list" | sort -uVr | head -n 5)

echo "$filtered_versions" > "$version_list"
