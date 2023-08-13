#!/bin/bash

function err_msg() {
    echo -en "error: $*\n" 1>&2

    #test for logger
    if which logger >/dev/null 2>&1 ; then
        logger --tag "ebuild-verbump" --priority user.error "$*" 1>&2
    else
        echo -en "error: this script requires logger https://github.com/util-linux/util-linux\n\t\t( sys-apps/util-linux on Gentoo )" 1>&2
        exit 1
    fi
}

#test for jq
if ! which jq >/dev/null 2>&1 ; then
    err_msg "this script requires jq https://stedolan.github.io/jq/\n\t\t( app-misc/jq on Gentoo )"
    exit 1
fi
#test for curl
if ! which curl >/dev/null 2>&1 ; then
    err_msg "this script requires curl https://curl.haxx.se/\n\t\t( net-misc/curl on Gentoo )"
    exit 1
fi
#test for git
if ! which git >/dev/null 2>&1 ; then
    err_msg "this script requires git https://www.git-scm.com/\n\t\t( dev-vcs/git on Gentoo )"
    exit 1
fi

## jq function to handle stdin, arg[n], and suppress stderr
function jq_cmd() {
    local err_code jq_args
    #jq with --exit-status will return non-zero on not found / null
    jq_args="--exit-status --raw-output"
    if [ ! -p /dev/stdin ] ; then
        err_msg "jq_cmd not fed with stdin"
        return 1
    elif [ -z "$1" ] ; then
        err_msg "jq_cmd not provided with filter"
        return 1
    fi
    #silence jq stderr output
    # jq filter not found has no output, and returns non zero
    # jq input not json outputs 'jq: parse error: <something> at line x, column y', and returns non zero
    #shellcheck disable=SC2086 #actually want word splitting
    cat -|jq ${jq_args} "$@" 2>/dev/null
    err_code="$?"
    if [ ${err_code} -gt 0 ] ; then
        err_msg "jq failed to parse"
        return 1
    fi
}

## curl function to keep quoting sane
function curl_cmd() {
    local curl_out err_code
    #curl --fail will give us an exit code of 22 for 404s
    curl_out=$(curl --fail --header 'Accept: application/vnd.github+json' --silent "$@")
    err_code="$?"
    if [ ${err_code} -gt 0 ] ; then
        err_msg "curl response \"${err_code}\" for URI \"$*\""
        #jq will fail to parse 'FAIL'
        echo "FAIL"
        return 1
    else
        echo "${curl_out}"
    fi
}

## collect our package variables
function vars_github_api() {
    local tag_sha commit_sha
    #grab latest release tag (version)
    pkg_ver="$(curl_cmd "${pkg_git_base}/releases/latest"|jq_cmd '.tag_name')" || return 1
    #get version major.minor
    pkg_maj_min="$(echo "${pkg_ver}"|grep -Eo '[0-9]+\.[0-9]+')"
    #using release tag grab tag sha
    tag_sha="$(curl_cmd "${pkg_git_base}/git/ref/tags/${pkg_ver}" |jq_cmd '.object.sha')" || return 1
    #using tag sha grab commit sha
    commit_sha="$(curl_cmd "${pkg_git_base}/git/tags/${tag_sha}" |jq_cmd '.object.sha')" || return 1

    #iterate over git sub-modules and get mod info using commit sha
    local cur_sub_module sub_mod_info sub_mod_sha sub_mod_fail
    for cur_sub_module in "${pkg_sub_modules[@]}" ; do
        #pulling into sub_mod_info to reduce curl invocations
        #  ${var#*:} remove everything infront of first : (including the first :)
        sub_mod_info="$(curl_cmd "${cur_sub_module#*:}?ref=${commit_sha}")" || {
            #space added to end to ensure readability
            sub_mod_fail+="${cur_sub_module%%:*} "
            continue
        }
        #test that dir is actually a git sub-module
        if [ "$(echo "${sub_mod_info}"|jq_cmd '.type')" != "submodule" ]; then
            #upstream changed layout or dependancies
            #  ${var%%:*} remove everything after first : (including the first :)
            err_msg "upstream changes to ${cur_sub_module%%:*} submodule, bailing out"
            return 1
        else
            #extract sha from saved json
            sub_mod_sha=$(echo "${sub_mod_info}"|jq_cmd '.sha')
	        if [ "${sub_mod_sha}" = "" ] || [ "${sub_mod_sha}" = "null" ]; then
                #issue with github api?
                err_msg "could not get sha for ${cur_sub_module%%:*} submodule, api issue?"
                return 1
            fi
        fi
        #indirect parameter expansion, setting the eventual ebuild variable to it's sha value
        export "${cur_sub_module%%:*}"="${sub_mod_sha}"
    done
    if [ -n "${sub_mod_fail[*]}" ] ; then
        err_msg "failed to get api info for submodules ${sub_mod_fail[*]}"
        return 1
    fi
}

## replace variable strings in the ebuild
function update_ebuild() {
    if [ -e "${ebuild}" ] ; then
        err_msg "no changes needed $pkg $pkg_ver ebuild exists"
        #return 1 to short circuit running git [add, commit, push]
        return 1
    fi

    cp -v "${from}" "${ebuild}" ||  { err_msg "unable to copy template ${from}" ; return 1 ; }
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

    ebuild "${ebuild}" manifest
}

function clone_overlay() {
    if [[ ! -d "${workdir}" ]]; then
        cd "${basedir}"
        git clone "${repo}" || return 1
    else
        cd "${workdir}"
        git pull || return 1
    fi
}

## update the overlay repo
function push_to_overlay() {
    cd "${workdir}" || { err_msg "could not change to ${workdir} dir" ; return 1 ; }

    update_ebuild || return

    #repoman full --include-dev --without-mask || { err_msg "repoman checks failed" ; return 1 ; }

    git add ${ebuild} Manifest || { err_msg "git staging changes failed" ; return 1 ; }
    git commit -asm "${pkg} auto-verbump $(basename ${ebuild})" || { err_msg "git commit failed" ; return 1 ; }
    git push || { err_msg "git push failed" ; return 1 ; }
}

### vim: ts=4 sts=4 sw=4 expandtab
