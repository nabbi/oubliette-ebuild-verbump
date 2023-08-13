#!/bin/bash

## remove next two lines once configured
echo "error: script not configured"
exit 1

#local git repo and package subdir
#  if using ~/SOMEPATH remove quotes
repo="SOMEPATH"
#package name
pkg="SOMEPACKAGE"
#upstrean repo
pkg_git_base="https://api.github.com/repos/PROJECT/REPO"
#git submodules and their variable in the ebuild
# Format EBUILD_VARIABLE:"full_git_sub_path"
#  example: MY_CRUD_V:"${pkg_git_base}/contents/web/api/app/Plugin/Crud"
pkg_sub_modules=(

)

#import our common functions
source $(dirname "$(readlink -f "$0")")/inc-common.sh

vars_github_api || { err_msg "could not get package variables" ; exit 1 ; }

ebuild="${pkg}-${pkg_ver}.ebuild"
#if there is a live build for this major.minor then base upon that
# this caters for situations where upstream has different dependencies
# between stable and dev branches
if [ -e "${repo}/${pkg}-${pkg_maj_min}.9999.ebuild" ]; then
    from="${pkg}-${pkg_maj_min}.9999.ebuild"
else
    from="${pkg}-9999.ebuild"
fi

push_to_overlay

### vim: ts=4 sts=4 sw=4 expandtab
