#!/bin/bash

#git repo and package subdir
repo=~/oubliette-overlay/www-misc/zoneminder
pkg="zoneminder"

version=$(curl --silent https://update.zoneminder.com/version.txt)
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

