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

lint_cmd="j2lint --stdin --json"

if [ -n "${J2LINT_IGNORE_RULES}" ]; then
    lint_cmd="${lint_cmd} --ignore ${J2LINT_IGNORE_RULES}"
fi

if [ -n "${J2LINT_WARNING_RULES}" ]; then
    lint_cmd="${lint_cmd} --warn ${J2LINT_WARNING_RULES}"
fi

if ! lint_cmd_check="$(echo "" | ${lint_cmd} 2>&1)"; then
    echo "Invalid arguments provided for lint command: ${lint_cmd}"
    echo "Command output:"
    echo "------"
    echo "${lint_cmd_check}"
    echo "------"
    echo ""
    echo "Invalid j2lint arguments provided, exiting" >&2
    exit 3
fi

if [ "${VALIDATE_ALL_CODEBASE}" = "true" ]; then
    echo "Linting entire code base"

    all_files="$(git ls-tree --name-only -r HEAD)"
else
    echo "Linting new or changed files"

    if [ "${GITHUB_EVENT_NAME}" = "pull_request" ]; then
        GITHUB_SHA="$(jq -r .pull_request.head.sha < "${GITHUB_EVENT_PATH}")"
    fi

    git config --global --add safe.directory "${GITHUB_WORKSPACE}"
    git checkout --quiet "${DEFAULT_BRANCH}"
    git checkout --quiet "${GITHUB_SHA}"

    if [ "${GITHUB_EVENT_NAME}" = "push" ]; then
        all_files="$(git diff-tree --no-commit-id --name-only -r "${GITHUB_SHA}")"

        if [ -z "${all_files}" ]; then
            all_files="$(git diff --name-only --diff-filter=d "${DEFAULT_BRANCH}...${GITHUB_SHA}")"
        fi
    else
        all_files="$(git diff --name-only --diff-filter=d "${DEFAULT_BRANCH}...${GITHUB_SHA}")"
    fi

    echo ""
    echo "New or changed files detected by git:"
    echo "${all_files}"
fi

echo ""
echo "Jijna2 files to lint:"
check_files=""
for file in ${all_files}; do
    if [[ "${file}" =~ ${J2LINT_FILES_REGEX} ]] && [ -f "${file}" ]; then
        echo "  * ${file}"
        check_files="${check_files} ${file}"
    fi
done

if [ -z "${check_files}" ]; then
    echo "No jinja2 files to check"
    exit 0
else
    echo ""
    echo "Checking each jinja2 file with lint command: ${lint_cmd}"
fi

lint_errors=0
lint_warnings=0
for file in ${check_files}; do
    echo ""
    echo "-----------------------------------------"
    echo "Checking file: ${file}"
    echo "Command output:"
    echo "------"
    lint_result="$(${lint_cmd} < "${file}" || true)"
    echo "${lint_result}"
    echo "------"

    echo "${lint_result}" | \
        jq -r '.ERRORS[] | "::error file='"${file}"',line=\(.line_number)::\(.message) (\(.id))"'
    echo "${lint_result}" | \
        jq -r '.WARNINGS[] | "::warning file='"${file}"',line=\(.line_number)::\(.message) (\(.id))"'

    errors="$(echo "${lint_result}" | jq -r '.ERRORS | length')"
    lint_errors=$((lint_errors + errors))
    warnings="$(echo "${lint_result}" | jq -r '.WARNINGS | length')"
    lint_warnings=$((lint_warnings + warnings))

    echo "Linted ${file} with ${errors} error(s) and ${warnings} warning(s)"
    echo "-----------------------------------------"
done

echo ""
echo "Total errors: ${lint_errors}"
echo "Total warnings: ${lint_warnings}"

if [ "${lint_errors}" -gt 0 ]; then
    echo "Exiting with jinja2 linting errors"
    exit 2
fi
