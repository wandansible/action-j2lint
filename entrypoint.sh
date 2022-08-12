#!/bin/bash

set -euo pipefail

PATH="/opt/venv/bin:${PATH}"

default_files_regex='^.*\.(j2|jinja2|jinja)$'
default_ignore_rules=""
default_warning_rules=""
default_validate_all_codebase="false"
default_branch="main"

J2LINT_FILES_REGEX="${J2LINT_FILES_REGEX:-$default_files_regex}"
J2LINT_IGNORE_RULES="${J2LINT_IGNORE_RULES:-$default_ignore_rules}"
J2LINT_WARNING_RULES="${J2LINT_WARNING_RULES:-$default_warning_rules}"
VALIDATE_ALL_CODEBASE="${VALIDATE_ALL_CODEBASE:-$default_validate_all_codebase}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-$default_branch}"

if [ "${VALIDATE_ALL_CODEBASE}" = "true" ]; then
    git_files_cmd="git ls-tree --name-only -r HEAD"
else
    git fetch --quiet origin "${DEFAULT_BRANCH}"
    if [ -e ".git/shallow" ]; then
        git fetch --quiet --unshallow origin "${GITHUB_SHA}"
    fi
    git checkout --quiet "${DEFAULT_BRANCH}"
    git checkout --quiet "${GITHUB_SHA}"

    status=0
    git_base="$(git merge-base "${GITHUB_SHA}" "${DEFAULT_BRANCH}")" || status=$?
    if [ ! "${status}" = "0" ] || [ -z "${git_base}" ]; then
        git_base="${DEFAULT_BRANCH}"
    fi

    git_files_cmd="git diff --name-only ${GITHUB_SHA} ${git_base}"
fi

echo "Getting files from command: ${git_files_cmd}"
all_files="$(${git_files_cmd})"
echo ""

echo "Building jinja2 file list"
echo "-------------------------"
check_files=""
for file in ${all_files}; do
    if [[ "${file}" =~ ${J2LINT_FILES_REGEX} ]]; then
        echo "${file}"
        check_files="${check_files} ${file}"
    fi
done

lint_cmd="j2lint --stdin --json"

if [ -n "${J2LINT_IGNORE_RULES}" ]; then
    lint_cmd="${lint_cmd} --ignore ${J2LINT_IGNORE_RULES}"
fi

if [ -n "${J2LINT_WARNING_RULES}" ]; then
    lint_cmd="${lint_cmd} --warn ${J2LINT_WARNING_RULES}"
fi

if [ -z "${check_files}" ]; then
    echo "No jinja2 files to check"
else
    echo ""
    echo "Lint command: ${lint_cmd}"
fi
echo ""

exit_code=0
for file in ${check_files}; do
    echo "Checking file: ${file}"

    lint_result="$(${lint_cmd} < "${file}")" || exit_code=$?

    if [ ! "${exit_code}" = "0" ] && [ ! "${exit_code}" = "2" ] || [ -z "${lint_result}" ]; then
        echo "Lint command failed, exiting"
        exit "${exit_code}"
    fi

    echo "${lint_result}" | jq -r '.ERRORS[] | "::error file='"${file}"',line=\(.line_number)::\(.message) (\(.id))"'
    echo "${lint_result}" | jq -r '.WARNINGS[] | "::warning file='"${file}"',line=\(.line_number)::\(.message) (\(.id))"'

    errors="$(echo "${lint_result}" | jq -r '.ERRORS | length')"
    warnings="$(echo "${lint_result}" | jq -r '.WARNINGS | length')"
    echo "Linted ${file} with ${errors} error(s) and ${warnings} warning(s)"
    echo ""
done

if [ "${exit_code}" = "0" ]; then
    echo "All jinja2 files linted successfully"
else
    echo "Exiting with jinja2 linting errors"
fi
exit "${exit_code}"
