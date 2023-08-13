#!/bin/bash

#local git repo and package subdir
basedir="/opt"
workdir="${basedir}/oubliette-overlay-dev/www-misc/zoneminder"
repo="git@github.com:nabbi/oubliette-overlay-dev.git"
#package name
pkg="zoneminder"
ver="9999-r1"
#upstream repo
pkg_git_base="https://api.github.com/repos/ZoneMinder/zoneminder"
#git submodules and their variable in the ebuild
# Format EBUILD_VARIABLE:"full_git_sub_path"
#  example: MY_CRUD_V:"${pkg_git_base}/contents/web/api/app/Plugin/Crud"
pkg_sub_modules=(
MY_CRUD_V:"${pkg_git_base}/contents/web/api/app/Plugin/Crud"
MY_CAKEPHP_V:"${pkg_git_base}/contents/web/api/app/Plugin/CakePHP-Enum-Behavior"
MY_RTSP_V:"${pkg_git_base}/contents/dep/RtspServer"
)

#import our common functions
source $(dirname "$(readlink -f "$0")")/inc-common.sh

vars_github_api || { err_msg "could not get package variables" ; exit 1 ; }

clone_overlay || { err_msg "unable to refresh ${repo}" ; exit 1 ; }

ebuild="${workdir}/${pkg}-${pkg_ver}.ebuild"
#if there is a live build for this major.minor then base upon that
# this caters for situations where upstream has different dependencies
# between stable and dev branches
if [ -e "${workdir}/${pkg}-${pkg_maj_min}.${ver}.ebuild" ]; then
    from="${workdir}/${pkg}-${pkg_maj_min}.${ver}.ebuild"
else
    from="${workdir}/${pkg}-${ver}.ebuild"
fi

if [[ "$(push_to_overlay)" != "0" ]]; then
    exit 1
fi

### vim: ts=4 sts=4 sw=4 expandtab
