#!/bin/bash

#git repo and package subdir
repo=~/oubliette-overlay/www-misc/zoneminder
pkg="zoneminder"

# zm.com does not always reflect latest github release
#version=$(curl --silent https://update.zoneminder.com/version.txt)
version=$(curl --silent https://api.github.com/repos/ZoneMinder/zoneminder/releases/latest | grep tag_name | sed "s/,//" | sed 's/\s*"tag_name":\s*//' | sed 's/"//g')
ebuild="${pkg}-${version}.ebuild"
from="${pkg}-9999.ebuild"

cd ${repo}
git pull

if [ -e ${ebuild} ] ; then
    echo "no changes needed $pkg $version ebuild exists"
    exit
fi

cp -v ${from} ${ebuild}
ebuild ${ebuild} digest

git add .
git commit -asm "${pkg} auto-verbump"
git push

