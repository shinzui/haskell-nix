# Classify `haskell-nix-update refresh --dry-run` output into per-family update types.
#
# Input is the annotated stream the justfile `status` recipe builds, one section per family:
#
#   @family NAME       begins a section; everything until the next marker belongs to NAME
#   @error NAME TEXT   the dry run failed for NAME; TEXT is the first line of its stderr
#   - ...              a change line as emitted by the updater
#
# Set -v color=1 for ANSI highlighting. Detail lines stay uncoloured so the label
# column keeps its alignment.

function tag(current, addition) {
  return current == "" ? addition : current ", " addition
}

function append(store, key, item) {
  store[key] = store[key] == "" ? item : store[key] ", " item
}

function before(text, marker) {
  return substr(text, 1, index(text, marker) - 1)
}

function after(text, marker) {
  return substr(text, index(text, marker) + length(marker))
}

BEGIN {
  families = 0
  if (color) {
    bold = "\033[1m"; off = "\033[0m"
    git_colour = "\033[36m"; release_colour = "\033[35m"
    error_colour = "\033[31m"; ok_colour = "\033[32m"
  }
}

/^@family / {
  family = substr($0, 9)
  order[++families] = family
  next
}

/^@error / {
  detail = substr($0, 8)
  family = before(detail, " ")
  failure[family] = after(detail, " ")
  next
}

/^- / {
  line = substr($0, 3)
  if (index(line, ": ") == 0) next
  subject = before(line, ": ")
  detail = after(line, ": ")

  if (index(subject, "/") > 0) {
    family = before(subject, "/")
    package = after(subject, "/")
  } else {
    family = subject
    package = ""
  }

  if (index(detail, "GitHub revision ") == 1) {
    bump = after(detail, "GitHub revision ")
    revision[family] = substr(before(bump, " -> "), 1, 8) " -> " substr(after(bump, " -> "), 1, 8)
  } else if (index(detail, "GitHub version ") == 1) {
    bump = after(detail, "GitHub version ")
    append(source, family, package " " bump)
  } else if (index(detail, "Hackage version ") == 1) {
    bump = after(detail, "Hackage version ")
    append(release, family, package " " bump)
    republished[family "/" package] = 1
  } else if (index(detail, "published on Hackage at ") == 1) {
    append(release, family, package " first published at " after(detail, "published on Hackage at "))
    republished[family "/" package] = 1
  } else if (index(detail, "no longer published on Hackage") == 1) {
    append(withdrawn, family, package)
  } else if (index(detail, "Hackage hash ") == 1) {
    rehash_family[family "/" package] = family
    rehash_package[family "/" package] = package
  } else if (detail == "added") {
    append(membership, family, "+" package)
  } else if (detail == "removed") {
    append(membership, family, "-" package)
  } else {
    append(note, family, subject ": " detail)
  }
  next
}

END {
  # A hash change alongside a version change is expected; alone it means the release
  # was re-uploaded under the same version, which is worth calling out separately.
  for (key in rehash_family)
    if (!(key in republished))
      append(rehash, rehash_family[key], rehash_package[key])

  printed = 0
  stale = 0
  failed = 0
  current = ""

  for (index_ = 1; index_ <= families; index_++) {
    family = order[index_]
    tags = ""

    if (family in failure) {
      tags = error_colour "query-failed" off
    } else {
      if (revision[family] != "") tags = tag(tags, git_colour "git-commit" off)
      if (release[family] != "") tags = tag(tags, release_colour "hackage-release" off)
      if (source[family] != "") tags = tag(tags, "source-version")
      if (membership[family] != "") tags = tag(tags, "membership")
      if (withdrawn[family] != "") tags = tag(tags, "hackage-withdrawn")
      if (rehash[family] != "") tags = tag(tags, "hackage-rehash")
      if (note[family] != "") tags = tag(tags, "other")
    }

    if (tags == "") {
      current = current == "" ? family : current ", " family
      continue
    }

    if (printed++ > 0) print ""
    printf "%s%s%s  [%s]\n", bold, family, off, tags

    if (family in failure) {
      failed++
      printf "  %-17s %s\n", "query-failed", failure[family]
      continue
    }

    stale++

    if (revision[family] != "") printf "  %-17s %s\n", "git-commit", revision[family]
    if (release[family] != "") printf "  %-17s %s\n", "hackage-release", release[family]
    if (source[family] != "") printf "  %-17s %s\n", "source-version", source[family]
    if (membership[family] != "") printf "  %-17s %s\n", "membership", membership[family]
    if (withdrawn[family] != "") printf "  %-17s %s\n", "hackage-withdrawn", withdrawn[family]
    if (rehash[family] != "") printf "  %-17s %s\n", "hackage-rehash", rehash[family]
    if (note[family] != "") printf "  %-17s %s\n", "other", note[family]

    if (revision[family] != "" && release[family] == "" && source[family] == "" \
        && membership[family] == "" && withdrawn[family] == "" && rehash[family] == "")
      print "  (unreleased commits: no version moved and no Hackage change)"
  }

  if (printed > 0) print ""
  printf "%d of %d families need updates.\n", stale, families
  if (failed > 0) printf "%s%d could not be queried%s (transient failures are safe to rerun).\n", error_colour, failed, off
  if (current != "") printf "%sUp to date%s: %s\n", ok_colour, off, current
}
