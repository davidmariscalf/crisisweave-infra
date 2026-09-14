#!/bin/sh
set -eu

cd "$(dirname "$0")"
umask 077

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 BACKUP_DIRECTORY [OUTPUT_DIRECTORY]" >&2
  exit 2
fi

backup="$1"
out_root="${2:-./offsite}"
recipient="${CW_BACKUP_AGE_RECIPIENT:-}"

if [ -z "$recipient" ]; then
  echo "CW_BACKUP_AGE_RECIPIENT must contain an age public recipient" >&2
  exit 2
fi
if ! command -v age >/dev/null 2>&1; then
  echo "age is required to create an encrypted off-host bundle" >&2
  exit 1
fi
if [ ! -d "$backup" ]; then
  echo "backup directory not found: $backup" >&2
  exit 1
fi

name="$(basename "$backup")"
case "$name" in
  ''|*[!A-Za-z0-9._:-]*)
    echo "unsafe backup directory name" >&2
    exit 1
    ;;
esac

# Never export a snapshot that has not passed the complete read-only restore drill.
sh restore-drill.sh "$backup" >/dev/null

mkdir -p "$out_root"
chmod 700 "$out_root" 2>/dev/null || true

final="$out_root/crisisweave-backup-$name.tar.age"
tmp="$out_root/.crisisweave-backup-$name.tar.age.$$"
checksum="$final.sha256"

cleanup() {
  rm -f "$tmp"
}
trap cleanup EXIT INT TERM

# Stream the exact verified backup set directly into age. No plaintext tarball is
# written to disk. The recipient is a public key; the corresponding private key
# should live off-host in a password/secret manager or recovery vault.
tar -C "$backup" -cf - \
  platform.sqlite3 \
  private.sqlite3 \
  worksites.sqlite3 \
  AUDIT_SEALS.json \
  SHA256SUMS \
  METADATA \
  | age -r "$recipient" -o "$tmp"

chmod 600 "$tmp"
mv "$tmp" "$final"
trap - EXIT INT TERM

(
  cd "$out_root"
  sha256sum "$(basename "$final")" > "$(basename "$checksum")"
)
chmod 600 "$checksum"

printf '%s\n' "$final"
