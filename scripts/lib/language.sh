# Shared language detection for generated standalone entry points.
# Compatible with POSIX sh and macOS Bash 3.2.

# Return en/zh for supported locale names; return nothing for unknown names.
dotgraft_locale_language() {
  case "$1" in
    zh | zh_* | zh-* | Chinese*) printf 'zh\n' ;;
    en | en_* | en-* | English*) printf 'en\n' ;;
  esac
}

# Explicit overrides win, followed by locale variables and macOS preferences.
# Do not change LC_ALL/LANG: external tools retain their own locale behavior.
dotgraft_detect_language() {
  if [ -n "${DOTGRAFT_LANG:-}" ]; then
    case "$DOTGRAFT_LANG" in
      en | zh) printf '%s\n' "$DOTGRAFT_LANG" ;;
      *) printf 'en\n' ;;
    esac
    return
  fi

  # The first populated locale is authoritative. An unsupported locale falls
  # back to English rather than a lower-priority, potentially stale variable.
  dotgraft_locale="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
  case "$dotgraft_locale" in
    '' | C | POSIX | C.UTF-8 | C.utf8) ;;
    *)
      dotgraft_language="$(dotgraft_locale_language "$dotgraft_locale")"
      printf '%s\n' "${dotgraft_language:-en}"
      return
      ;;
  esac

  # macOS shells may expose no meaningful locale. Read only the first preferred
  # UI language; a secondary Chinese language must not override the primary one.
  if command -v defaults > /dev/null 2>&1; then
    dotgraft_preferred="$({ defaults read -g AppleLanguages 2> /dev/null || true; } | awk '
      /\(/ { next }
      { gsub(/[",[:space:]]/, ""); if (length && $0 != ")") { print; exit } }
    ')"
    dotgraft_language="$(dotgraft_locale_language "$dotgraft_preferred")"
    printf '%s\n' "${dotgraft_language:-en}"
  else
    printf 'en\n'
  fi
}
