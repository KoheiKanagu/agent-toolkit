#!/usr/bin/env bash
# Wait for or check GitHub Copilot code review on a pull request.
#
# Exit codes:
#   0  review on current HEAD, 0 line comments
#   1  review on current HEAD, 1+ line comments
#   2  not requested, no review on HEAD, timeout, or usage/API error
set -euo pipefail

USAGE='Usage: wait-copilot-review.sh [--check] [--timeout SEC] [--interval SEC] [PR]'

CHECK_ONLY=0
TIMEOUT_SEC=600
INTERVAL_SEC=15
PR_SPEC=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      CHECK_ONLY=1
      shift
      ;;
    --timeout)
      if [[ $# -lt 2 || "$2" == -* ]]; then
        echo "$USAGE" >&2
        exit 2
      fi
      TIMEOUT_SEC="$2"
      shift 2
      ;;
    --interval)
      if [[ $# -lt 2 || "$2" == -* ]]; then
        echo "$USAGE" >&2
        exit 2
      fi
      INTERVAL_SEC="$2"
      shift 2
      ;;
    -h|--help)
      echo "$USAGE"
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "$USAGE" >&2
      exit 2
      ;;
    *)
      if [[ -n "$PR_SPEC" ]]; then
        echo "$USAGE" >&2
        exit 2
      fi
      PR_SPEC="$1"
      shift
      ;;
  esac
done

if [[ $# -gt 0 ]]; then
  echo "$USAGE" >&2
  exit 2
fi

if ! [[ "$TIMEOUT_SEC" =~ ^[0-9]+$ && "$INTERVAL_SEC" =~ ^[0-9]+$ ]]; then
  echo "timeout and interval must be non-negative integers" >&2
  exit 2
fi

if [[ "$INTERVAL_SEC" -eq 0 ]]; then
  echo "interval must be greater than 0" >&2
  exit 2
fi

for cmd in gh jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "required command not found: $cmd" >&2
    exit 2
  fi
done

# Prints: requested<TAB>head_sha<TAB>review_id<TAB>line_comments
# review_id empty when no Copilot review exists on current HEAD.
evaluate() {
  local pr_json owner repo number url head_sha
  local reviews_json comments_json
  local requested review_id line_comments

  if [[ -n "$PR_SPEC" ]]; then
    pr_json="$(gh pr view "$PR_SPEC" --json number,url,headRefOid)" || {
      echo "failed to resolve pull request: $PR_SPEC" >&2
      exit 2
    }
  else
    pr_json="$(gh pr view --json number,url,headRefOid)" || {
      echo "failed to resolve pull request for the current branch" >&2
      exit 2
    }
  fi

  number="$(jq -r '.number' <<<"$pr_json")"
  url="$(jq -r '.url' <<<"$pr_json")"
  head_sha="$(jq -r '.headRefOid' <<<"$pr_json")"
  if [[ -z "$number" || "$number" == "null" || -z "$head_sha" || "$head_sha" == "null" ]]; then
    echo "failed to resolve pull request" >&2
    exit 2
  fi

  if [[ "$url" =~ github.com/([^/]+)/([^/]+)/pull/ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
  else
    echo "failed to parse owner/repo from $url" >&2
    exit 2
  fi

  gql_json="$(
    NO_COLOR=1 gh api graphql \
      -f owner="$owner" \
      -f name="$repo" \
      -F number="$number" \
      -f query='
        query($owner: String!, $name: String!, $number: Int!) {
          repository(owner: $owner, name: $name) {
            pullRequest(number: $number) {
              reviewRequests(first: 50) {
                nodes {
                  requestedReviewer {
                    __typename
                    ... on Bot { login }
                    ... on User { login }
                  }
                }
              }
            }
          }
        }
      '
  )" || {
    echo "failed to query review requests for ${owner}/${repo}#${number}" >&2
    exit 2
  }

  if jq -e '(.errors | type == "array") and (.errors | length > 0)' <<<"$gql_json" >/dev/null \
    || jq -e '.data.repository.pullRequest == null' <<<"$gql_json" >/dev/null; then
    echo "failed to query review requests for ${owner}/${repo}#${number}" >&2
    exit 2
  fi

  requested="$(
    jq -c '
      [
        .data.repository.pullRequest.reviewRequests.nodes[]?
        | .requestedReviewer.login // empty
      ]
    ' <<<"$gql_json"
  )"

  if jq -e --argjson logins "$requested" -n '
      $logins | map(test("copilot-pull-request-reviewer") or . == "Copilot" or . == "copilot") | any
    ' >/dev/null; then
    requested="true"
  else
    requested="false"
  fi

  reviews_json="$(
    NO_COLOR=1 gh api --paginate "repos/${owner}/${repo}/pulls/${number}/reviews" \
      --jq '[.[] | {id, login: .user.login, commit_id, submitted_at: .submitted_at}]'
  )" || {
    echo "failed to list reviews for ${owner}/${repo}#${number}" >&2
    exit 2
  }
  reviews_json="$(jq -s 'add // []' <<<"$reviews_json")"

  review_id="$(
    jq -r --arg head "$head_sha" '
      [
        .[]
        | select((.login // "") | test("copilot-pull-request-reviewer"))
        | select(.commit_id == $head)
      ]
      | sort_by(.submitted_at)
      | last
      | .id // empty
    ' <<<"$reviews_json"
  )"

  line_comments=0
  if [[ -n "$review_id" ]]; then
    comments_json="$(
      NO_COLOR=1 gh api --paginate \
        "repos/${owner}/${repo}/pulls/${number}/reviews/${review_id}/comments" \
        --jq '[.[].id]'
    )" || {
      echo "failed to list review comments for review ${review_id}" >&2
      exit 2
    }
    comments_json="$(jq -s 'add // []' <<<"$comments_json")"
    line_comments="$(jq 'length' <<<"$comments_json")"
  fi

  printf '%s\t%s\t%s\t%s\n' \
    "$requested" "$head_sha" "$review_id" "$line_comments"
}

report_and_exit() {
  local requested="$1"
  local head_sha="$2"
  local review_id="$3"
  local line_comments="$4"
  local reason="$5"
  local code="$6"

  case "$code" in
    0)
      echo "PASS head=${head_sha} line_comments=${line_comments} review_id=${review_id}"
      ;;
    1)
      echo "FAIL_COMMENTS head=${head_sha} line_comments=${line_comments} review_id=${review_id}"
      ;;
    2)
      echo "FAIL_${reason} head=${head_sha} requested=${requested} review_id=${review_id:-none} line_comments=${line_comments}"
      ;;
  esac
  exit "$code"
}

decide() {
  local requested="$1"
  local head_sha="$2"
  local review_id="$3"
  local line_comments="$4"

  if [[ -n "$review_id" ]]; then
    if [[ "$line_comments" -eq 0 ]]; then
      report_and_exit "$requested" "$head_sha" "$review_id" "$line_comments" PASS 0
    fi
    report_and_exit "$requested" "$head_sha" "$review_id" "$line_comments" COMMENTS 1
  fi

  if [[ "$requested" == "true" ]]; then
    return 1
  fi
  report_and_exit "$requested" "$head_sha" "" 0 NOT_REQUESTED 2
}

read_evaluation() {
  local row
  row="$(evaluate)" || exit 2
  IFS=$'\t' read -r requested head_sha review_id line_comments <<<"$row"
}

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  read_evaluation
  decide "$requested" "$head_sha" "$review_id" "$line_comments"
  report_and_exit "$requested" "$head_sha" "${review_id:-}" "${line_comments:-0}" PENDING 2
fi

deadline=$((SECONDS + TIMEOUT_SEC))
while (( SECONDS < deadline )); do
  read_evaluation
  decide "$requested" "$head_sha" "$review_id" "$line_comments"
  remaining=$((deadline - SECONDS))
  if (( remaining <= 0 )); then
    break
  fi
  echo "waiting for copilot-pull-request-reviewer on ${head_sha} (${remaining}s left)" >&2
  sleep_for="$INTERVAL_SEC"
  if (( sleep_for > remaining )); then
    sleep_for="$remaining"
  fi
  sleep "$sleep_for"
done

read_evaluation
decide "$requested" "$head_sha" "${review_id:-}" "${line_comments:-0}"
report_and_exit "${requested:-false}" "${head_sha:-unknown}" "${review_id:-}" "${line_comments:-0}" TIMEOUT 2
