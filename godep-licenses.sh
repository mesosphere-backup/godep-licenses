#!/usr/bin/env bash

# Extract Godep package license information.
# Generates a (csv or markdown) table of Godep dependencies and their license.
# Requires:
#    jq (https://stedolan.github.io/jq/)
#    ninka (http://ninka.turingmachine.org/)
#    NINKA env var (optional) set to the path of the ninka executable
#    Bash version new enough to support associative arrays
# Usage Example:
#    NINKA=~/Downloads/ninka-1.3/ninka.pl ./godep-license.sh -e github.com/stretchr/testify:MIT

set -o errexit
set -o nounset
set -o pipefail

# File name
readonly PROGNAME=$(basename $0)

# American and UK spelling
readonly LICENSE_FILES="LICENSE LICENSE.txt LICENSE.md LICENCE LICENCE.txt LICENCE.md"
readonly README_FILES="README README.txt README.md"
readonly GODEP_SRC="Godeps/_workspace/src"

# default to the current directory
REPO_PATH="$(pwd)"

# default to comma sepperated values
OUTPUT_FORMAT="csv"

declare -A EXEMPTIONS


function main() {
  parse-args "$@"
  [ -z "${OUTPUT_FORMAT:-}" ] && echo "Invalid output. Use --help to see the valid syntax." >&2 && exit 1
  find-ninka
  find-jq

  case "${OUTPUT_FORMAT}" in
  csv) print-csv;;
  md)  print-markdown;;
  *) echo "Invalid output format. Use --help to see the valid formats." >&2 && exit 1
  esac
}

function find-ninka() {
  if [ -z "${NINKA:-}" ]; then
    NINKA="$(which ninka)"
    [ -z "${NINKA:-}" ] && echo "No ninka found in PATH. Install ninka or define its path with the NINKA environment variable." >&2 && exit 1
  fi
  echo "Using Ninka: ${NINKA}" >&2
}

function find-jq() {
  JQ="$(which jq)"
  [ -z "${JQ:-}" ] && echo "No jq found in PATH. Install jq." >&2 && exit 1
  echo "Using jq: ${JQ}" >&2
}

function usage() {
	echo "godep-licenses - godep dependency license report generation tool"
	echo
	echo "Usage: $PROGNAME [options]..."
	echo
	echo "Options:"
	echo
	echo "  -h, --help"
	echo "      This help text."
	echo
	echo "  -e <package:license>, --exemption <package:license>"
	echo "      Exemption license for a specific package"
	echo
	echo "  -o <format>, --output <format>"
	echo "      Output format. One of:"
	echo "        csv - comma separated values (default)"
	echo "        md  - markdown"
	echo
	echo "  -p <repo>, --path <repo>"
	echo "      Path to the root of a Golang repository that contains a Godep dir (defaults to current dir)"
	echo
	echo "  --"
	echo "      Do not interpret any more arguments as options."
	echo
}

function parse-args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -e|--exemption)
      local exemption="$2"
      [ -z "${exemption:-}" ] && echo "Invalid exemption. Use --help to see the valid syntax." >&2 && exit 1
      local pkg="$(echo "${exemption}" | cut -d':' -f1)"
      [ -z "${pkg:-}" ] && echo "Invalid exemption package. Use --help to see the valid syntax." >&2 && exit 1
      local license="$(echo "${exemption}" | cut -d':' -f2)"
      [ -z "${license:-}" ] && echo "Invalid exemption license. Use --help to see the valid syntax." >&2 && exit 1
      EXEMPTIONS["${pkg}"]="${license}"

      # Jump over <file>, in case "-" is a valid input file (keyword to standard input).
      # Jumping here prevents reaching "-*)" case when parsing <file>
      shift
      ;;
    -o|--output)
      OUTPUT_FORMAT="$2"
      [ -z "${OUTPUT_FORMAT:-}" ] && echo "Invalid output. Use --help to see the valid syntax." >&2 && exit 1
      ;;
    -p|--path)
      REPO_PATH="$2"
      [ -z "${REPO_PATH:-}" ] && echo "Invalid path. Use --help to see the valid syntax." >&2 && exit 1
      ;;
    --)
      break
      ;;
    -*)
      echo "Invalid option '$1'. Use --help to see the valid options" >&2
      exit 1
      ;;
    # an option argument, continue
    *)	;;
    esac
    shift
  done
}

function license-file() {
  local PKG="${1}"
  local L=""
  local R=""
  for L in ${LICENSE_FILES}; do
    if [ -f "${REPO_PATH}/${GODEP_SRC}/${PKG}/${L}" ]; then
      echo "${GODEP_SRC}/${PKG}/${L}"
      return
    fi
  done
  for R in ${README_FILES}; do
    if [ -f "${REPO_PATH}/${GODEP_SRC}/${PKG}/${R}" ]; then
      echo "${GODEP_SRC}/${PKG}/${R}"
      return
    fi
  done
}

function license() {
  local FILE_PATH="${1}"
  local NINKA_OUT="$("${NINKA}" "${FILE_PATH}")"
  echo "${NINKA_OUT}" | sed \
    -e 's/;/,/g' \
    -e 's/,UNKNOWN//g' \
    -e 's/,Copyright//g' \
    -e 's/,-*[0-9][0-9]*//g' \
    -e 's/^.*,//' \
    -e "s;^${FILE_PATH}$;NONE;"
}

function pkg-file-license() {
  cat "${REPO_PATH}/Godeps/Godeps.json" | "${JQ}" -r ".Deps[].ImportPath" | sort -f |
    while read PACKAGE; do
      local P="${PACKAGE}"
      local F=""
      local L="NONE"
      while [ "${P}" != "." ]; do
        # check for packages with hard-coded exceptions
        if [ ! -z "${EXEMPTIONS["${P}"]:-}" ]; then
          L="${EXEMPTIONS["${P}"]}"
          echo "${PACKAGE},${P}/EXEMPTION,${L}"
          break
        fi
        F="$(license-file "${P}")"
        if [ ! -z "${F}" ] && [ -f "${REPO_PATH}/${F}" ]; then
          L="$(license "${REPO_PATH}/${F}")"
          if [ "${L}" != "NONE" ]; then
            echo "${PACKAGE},${F},${L}"
            break
          fi
        fi
        P=$(dirname "${P}")
      done
      if [ "${L}" != "NONE" ]; then
        continue
      fi
      FILE_LICENSE=$(
        (cd "${REPO_PATH}/${GODEP_SRC}"; find "${PACKAGE}" -name "*.go") | while read GO_FILE; do
          local LL="$(license "${REPO_PATH}/${GODEP_SRC}/${GO_FILE}")"
          if [ "${LL}" != "NONE" ] && [ "${LL}" != "${L}" ]; then
            L="${LL}"
            echo "${GO_FILE},${L}"
          fi
        done
      )
      if [ -z "${FILE_LICENSE}" ]; then
        FILE_LICENSE="UNKNOWN,UNKNOWN"
      fi
      echo "${PACKAGE},${FILE_LICENSE}"
    done
}

# de-dupes pkg-file-license based on license file
function print-csv-body() {
  local PREV_LICENSE_FILE=""
  pkg-file-license | while read LINE; do
    local PKG="$(echo "${LINE}" | cut -d',' -f1)"
    local LICENSE_FILE="$(echo "${LINE}" | cut -d',' -f2)"
    local LICENSE="$(echo "${LINE}" | cut -d',' -f3)"
    if [ "${LICENSE_FILE}" == "UNKNOWN" ]; then
      echo "${PKG},${LICENSE}"
    elif [ "${LICENSE_FILE}" != "${PREV_LICENSE_FILE}" ]; then
      PKG="$(dirname "${LICENSE_FILE}")"
      PKG="${PKG#${GODEP_SRC}/}" # strip prefix
      echo "${PKG},${LICENSE}"
    fi
    PREV_LICENSE_FILE="${LICENSE_FILE}"
  done
}

function print-csv() {
  echo "Generating CSV" >&2
  echo "Package,License"
  print-csv-body
}

function print-markdown() {
  echo "Generating Markdown" >&2
  echo "Dependency Licenses"
  echo "-------------------"
  echo
  echo "Package | License"
  echo "------- | -------"
  echo "$(print-csv-body | sed 's/,/ | /')"
}

main "$@"
