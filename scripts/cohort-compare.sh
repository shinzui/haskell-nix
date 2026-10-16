#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  cohort-compare --resolve-channel-lock FILE --input-path PATH
  cohort-compare --verify-import PROJECT --lock FILE --input-path PATH
  cohort-compare --compare-manifests BEFORE AFTER
  cohort-compare --freeze FILE_OR_HTTPS_URL --plan-json FILE [--all]
                 [--sources FILE] [--contributors FILE]

Compare every non-local dependency against frozen versions, source hashes,
Cabal metadata and flags. Local packages require declared contributor ownership.
Source and contributor manifests default to siblings of the freeze.
Exit codes: 0 match, 1 drift or unverifiable evidence, 2 invalid arguments.
Frozen Nix source/flag comparison is not available yet.
EOF
}

invalid() { echo "cohort-compare: $*" >&2; usage >&2; exit 2; }
lock=''; input_path=''; freeze=''; plan=''; sources=''; contributors=''; project=''; project_lock=''
before_manifest=''; after_manifest=''
declare -A seen=()
while (($#)); do
  option=$1
  if [[ -n ${seen[$option]:-} ]]; then invalid "duplicate option $option"; fi
  seen[$option]=1
  case "$option" in
    --help|-h) usage; exit 0 ;;
    --all) shift; continue ;;
    --compare-manifests)
      (($# >= 3)) && [[ -n $2 && -n $3 && $2 != --* && $3 != --* ]] || invalid "$option requires two files"
      before_manifest=$2
      after_manifest=$3
      shift 3 ;;
    --resolve-channel-lock|--input-path|--freeze|--plan-json|--sources|--contributors|--verify-import|--lock)
      (($# >= 2)) && [[ -n $2 && $2 != --* ]] || invalid "$option requires a value"
      case "$option" in
        --resolve-channel-lock) lock=$2 ;;
        --input-path) input_path=$2 ;;
        --freeze) freeze=$2 ;;
        --plan-json) plan=$2 ;;
        --sources) sources=$2 ;;
        --contributors) contributors=$2 ;;
        --verify-import) project=$2 ;;
        --lock) project_lock=$2 ;;
      esac
      shift 2 ;;
    *) invalid "unknown option $option" ;;
  esac
done

if [[ -n $before_manifest || -n $after_manifest ]]; then
  [[ -n $before_manifest && -n $after_manifest && -z $project && -z $project_lock && -z $input_path && -z $lock && -z $freeze && -z $plan && -z $sources && -z $contributors && -z ${seen[--all]:-} ]] || invalid 'manifest identity mode requires only --compare-manifests BEFORE AFTER'
  exec python3 "$manifest_tool" --compare "$before_manifest" "$after_manifest"
fi
if [[ -n $project || -n $project_lock ]]; then
  [[ -n $project && -n $project_lock && -n $input_path && -z $lock && -z $freeze && -z $plan && -z $sources && -z $contributors && -z ${seen[--all]:-} ]] || invalid 'import mode requires only --verify-import, --lock and --input-path'
  exec haskell-nix-update cohort verify-import --project "$project" --lock "$project_lock" --input-path "$input_path"
fi
if [[ -n $lock || -n $input_path ]]; then
  [[ -n $lock && -n $input_path && -z $freeze && -z $plan && -z $sources && -z $contributors && -z ${seen[--all]:-} ]] || invalid 'lock mode requires only --resolve-channel-lock and --input-path'
  exec haskell-nix-update cohort resolve-channel-lock --lock "$lock" --input-path "$input_path"
fi
[[ -n $freeze && -n $plan ]] || invalid 'plan mode requires --freeze and --plan-json'

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
fetch() {
  local from=$1 to=$2
  if [[ $from == https://* ]]; then
    curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --connect-timeout 10 --max-time 60 "$from" --output "$to"
  elif [[ $from == *://* ]]; then
    echo 'cohort-compare: only local paths and HTTPS URLs are accepted' >&2
    return 1
  else
    cp -- "$from" "$to"
  fi
}
sources=${sources:-${freeze%/*}/cohort-sources.json}
contributors=${contributors:-${freeze%/*}/contributors.json}
# A bare filename has no parent slash.
if [[ $freeze != */* ]]; then
  [[ -n ${seen[--sources]:-} ]] || sources=cohort-sources.json
  [[ -n ${seen[--contributors]:-} ]] || contributors=contributors.json
fi
fetch "$freeze" "$scratch/cohort.freeze" || exit 1
fetch "$sources" "$scratch/cohort-sources.json" || exit 1
fetch "$contributors" "$scratch/contributors.json" || exit 1
haskell-nix-update cohort compare-plan --freeze "$scratch/cohort.freeze" \
  --sources "$scratch/cohort-sources.json" --contributors "$scratch/contributors.json" --plan-json "$plan"
