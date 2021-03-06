#!/bin/bash

##
## This file is part of the `src-run/raspberry-scripts-bash` package.
##
## (c) Rob Frawley 2nd <rmf@src.run>
##
## For the full copyright and license information, view the LICENSE.md
## file distributed with this source code.
##

#
# resolve real path to this script
#

function get_self_dirpath() {
  local locator_bin
  local located_scr

  for b in readlink realpath; do
    if locator_bin="$(command -v "${b}")"; then
      break
    fi
  done

  if [[ -n ${locator_bin} ]] && located_scr="$("${locator_bin}" -e "${BASH_SOURCE[0]}")"; then
    printf -- '%s' "$(dirname "${located_scr}")"
    return 0
  fi

  return 255
}

#
# get available package version from cache
#

function get_cache_pkg_ver() {
  local name="${1}"

  apt show "${name}" 2> /dev/null \
    | grep -oE '^Version: .+$' 2> /dev/null \
    | cut -d' ' -f2 2> /dev/null
}

#
# get installed package version
#

function get_local_pkg_ver() {
  local name="${1}"

  dpkg -s "${name}" 2> /dev/null \
    | grep -E '^Version: .+$' 2> /dev/null \
    | cut -d' ' -f2 2> /dev/null
}

#
# install passed packages (if not already)
#

function apt_install_packages() {
    local -a package_names=("${@}")

    printf -- 'Working to install %d packages using apt package manager ...\n' "${#package_names[@]}"

    for p in "${package_names[@]}"; do
      printf -- 'Working to install package "%s" (targeting version "%s") ... ' "${p}" "$(get_cache_pkg_ver "${p}")"

      if dpkg -s "${p}" 2> /dev/null | grep installed &> /dev/null; then
        printf -- '[skipped] (found version "%s")\n' "$(get_local_pkg_ver "${p}")"
      else
        export DEBIAN_FRONTEND=noninteractive

        if sudo apt install "${p}" --assume-yes --quiet &> "${logger_path}"; then
          printf -- '[success] (found version "%s")\n' "$(get_local_pkg_ver "${p}")"
        else
          printf -- '[failure]\nLogging file located at "%s" ... Exiting prematurely!\n' "${logger_path}"
          exit 255
        fi

        unset DEBIAN_FRONTEND
      fi
    done
}

#
# perform glances install operation
#

function install() {
  local script_path
  local logger_path

  if ! script_path="$(get_self_dirpath)"; then
    printf -- 'Failure to resolve locater executable to resolve path "%s" ... Exiting prematurely!\n' "${BASH_SOURCE[0]}"
    exit 255
  fi

  if cd "${script_path}" 2> /dev/null; then
    printf -- 'Located installation path of "%s" ...\n' "${script_path}"
  else
    printf -- 'Failure entering installation path of "%s" ... Exiting prematurely!\n' "${script_path}"
    exit 255
  fi

  "${script_path}/glances-remove.bash"

  logger_path="${script_path}/.glances-install.log"

  [[ ! -f ${logger_path} ]] && touch "${logger_path}"

  printf -- 'Logging installation to "%s" (tail this file for additional command output) ...\n' "${logger_path}"

  apt_install_packages python3 python3-pip python3-virtualenv

  printf -- 'Working to create virtual environment for "glances" using python (version %s) interpreter ... ' "$(python3 --version 2>&1 | cut -d' ' -f2)"

  if python3 -m virtualenv -p python3 "${script_path}" &> "${logger_path}"; then
    printf -- '[success]\n'
  else
    printf -- '[failure]\nLogging file located at "%s" ... Exiting prematurely!\n' "${logger_path}"
    exit 255
  fi

  printf -- 'Include of virtual environment activation source "%s" in progress ... ' "${script_path}/bin/activate"

  if . "${script_path}/bin/activate" &> "${logger_path}"; then
    printf -- '[success]\n'
  else
    printf -- '[failure]\nLogging file located at "%s" ... Exiting prematurely!\n' "${logger_path}"
    exit 255
  fi

  printf -- 'Working to install "glances (all)" package using pip (version %s) ... ' "$(pip --version | cut -d' ' -f2)"

  if pip install 'glances[all]' &> "${logger_path}"; then
    printf -- '[success]\n'
  else
    printf -- '[failure]\nLogging file located at "%s" ... Exiting prematurely!\n' "${logger_path}"
    exit 255
  fi

  printf -- 'Exiting installation script for "glances" without error (executable at "%s/bin/glances") ...\n' "${script_path}"

  rm "${logger_path}" 2> /dev/null
}

#
# invoke main sub routine
#

install
