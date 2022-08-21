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



#test for jq
if ! which jq >/dev/null 2>&1 ; then
    echo "this script requires jq https://stedolan.github.io/jq/ (app-misc/jq on Gentoo)"
    exit 1
fi
#test for curl
if ! which curl >/dev/null 2>&1 ; then
    echo "this script requires curl https://curl.haxx.se/ (net-misc/curl on Gentoo)"
    exit 1
fi
#test for git
if ! which git >/dev/null 2>&1 ; then
    echo "this script requires git https://www.git-scm.com/ (dev-vcs/git on Gentoo)"
    exit 1
fi

jq_cmd="jq --raw-output"
## curl function to keep quoting sane
function curl_cmd() {
    curl --header 'Accept: application/vnd.github+json' --silent "$@"
}

## collect our package variables
function vars_github_api() {
    local tag_sha commit_sha
    #grab latest release tag (version)
    pkg_ver="$(curl_cmd "${pkg_git_base}/releases/latest" |${jq_cmd} '.tag_name')"
    #get version major.minor
    pkg_maj_min="$(echo "${pkg_ver}"|grep -Eo '[0-9]+\.[0-9]+')"
    #using release tag grab tag sha
    tag_sha="$(curl_cmd "${pkg_git_base}/git/ref/tags/${pkg_ver}" |${jq_cmd} '.object.sha')"
    #using tag sha grab commit sha
    commit_sha="$(curl_cmd "${pkg_git_base}/git/tags/${tag_sha}" |${jq_cmd} '.object.sha')"

    #iterate over git sub-modules and get mod info using commit sha
    local cur_sub_module sub_mod_info sub_mod_sha
    for cur_sub_module in "${pkg_sub_modules[@]}" ; do
        #pulling into sub_mod_info to reduce curl invocations
        #  ${var#*:} remove everything infront of first : (including the first :)
        sub_mod_info="$(curl_cmd "${cur_sub_module#*:}?ref=${commit_sha}")"
        #test that dir is actually a git sub-module
        if [ "$(echo "${sub_mod_info}"|${jq_cmd} '.type')" != "submodule" ]; then
            #upstream changed layout or dependancies
            #  ${var%%:*} remove everything after first : (including the first :)
            echo "upstream changes to ${cur_sub_module%%:*} submodule, bailing out"
            exit 1
        else
            #extract sha from saved json
            sub_mod_sha=$(echo "${sub_mod_info}"|${jq_cmd} '.sha')
	        if [ "${sub_mod_sha}" = "" ] || [ "${sub_mod_sha}" = "null" ]; then
                #issue with github api?
                echo "could not get sha for ${cur_sub_module%%:*} submodule, api issue?"
                exit 1
            fi
        fi
        #indirect parameter expansion, setting the eventual ebuild variable to it's sha value
        export "${cur_sub_module%%:*}"="${sub_mod_sha}"
    done
}

## replace variable strings in the ebuild
function update_ebuild() {
    if [ -e "${ebuild}" ] ; then
        echo "no changes needed $pkg $pkg_ver ebuild exists"
        exit
    fi

    cp -v "${from}" "${ebuild}"
    #iterate over the sub modules and replace their current value with the retrieved sha
    local cur_sub_module ebld_var ebld_sha
    for cur_sub_module in "${pkg_sub_modules[@]}" ; do
        #the variable name
        ebld_var="${cur_sub_module%%:*}"
        #indirect expansion for the sha_hash
        ebld_sha="${!ebld_var}"
        #search ^EBUILD_VAR="*" keep EBUILD_VAR replace ="*" with ="variable_sha"
        # note if the var ever has an escaped " the sed will fail successfully
        sed -i -E -e "s/^(${ebld_var})=\"[^\"]*\"/\1=\"${ebld_sha}\"/" "${ebuild}"
    done

#    ebuild "${ebuild}" digest #depreciated
    ebuild "${ebuild}" manifest
}

## update the overlay repo
function push_to_overlay() {
    cd "${repo}" || { echo "could not change to ${repo} dir" ; return 1 ; }
    git pull

    update_ebuild

    git add .
    git commit -asm "${pkg} auto-verbump"
    git push
}

vars_github_api

ebuild="${pkg}-${pkg_ver}.ebuild"
#if there is a live build for this major.minor then base upon that
# this caters for situations where upstream has different dependencies
# between stable and dev branches
if [ -e "${pkg}-${pkg_maj_min}.9999.ebuild" ]; then
    from="${pkg}-${pkg_maj_min}.9999.ebuild"
else
    from="${pkg}-9999.ebuild"
fi

push_to_overlay

### vim: ts=4 sts=4 sw=4 expandtab
