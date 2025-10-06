#!/usr/bin/env bash
set -euo pipefail

# Env defaults (overridden by workflow envs)
: "${ISO_LABEL:=FEDORA_TREZOR}"
: "${ISO_BASENAME:=fedora-live-trezor}"
: "${TREZOR_FPR:=EB483B26B078A4AA1B6F425EE21B6950A2ECB65C}"
: "${TREZOR_KEY_URL:=https://trezor.io/security/satoshilabs-2021-signing-key.asc}"
: "${TREZOR_TAG:=}"
OUT_DIR="/workspace/out"

echo "==> Installing compose toolchain"
dnf -y install lorax lorax-lmc-novirt pykickstart anaconda-tui \
               git jq curl gnupg2 ca-certificates xorriso

FEDORA_VER="$(rpm -E %fedora)"
echo "==> Fedora detected: ${FEDORA_VER}"

echo "==> Cloning fedora-kickstarts"
WORKDIR="$(mktemp -d)"
pushd "$WORKDIR" >/dev/null
git clone --depth 1 https://pagure.io/fedora-kickstarts.git
cd fedora-kickstarts
REM="f${FEDORA_VER}"
if git ls-remote --heads origin "$REM" | grep -q "$REM"; then
  git fetch --depth=1 origin "refs/heads/${REM}:refs/heads/${REM}"
  git switch "$REM"
else
  echo "   Release branch $REM not found; staying on $(git rev-parse --abbrev-ref HEAD)."
fi
KSDIR="$PWD"
popd >/dev/null

echo "==> Preparing Kickstart from template"
TEMPLATE="/workspace/scripts/fedora-live/trezor-overlay.ks.in"
cp "$TEMPLATE" trezor-overlay.ks
sed -i \
  -e "s|__KSDIR__|${KSDIR}|g" \
  -e "s|__TREZOR_TAG__|${TREZOR_TAG}|g" \
  -e "s|__TREZOR_KEY_URL__|${TREZOR_KEY_URL}|g" \
  -e "s|__TREZOR_FPR__|${TREZOR_FPR}|g" \
  trezor-overlay.ks

echo "==> Flattening Kickstart"
ksflatten -c trezor-overlay.ks -o trezor-flat.ks

OUT="${ISO_BASENAME}-F${FEDORA_VER}-x86_64.iso"
echo "==> Building ISO: ${OUT}"
livemedia-creator \
  --ks trezor-flat.ks \
  --no-virt \
  --resultdir /var/lmc \
  --project Fedora-Trezor-Live \
  --make-iso \
  --volid "${ISO_LABEL}" \
  --iso-only \
  --iso-name "${OUT}" \
  --releasever "${FEDORA_VER}" \
  --macboot

echo "==> Collecting ISO(s)"
mkdir -p "${OUT_DIR}"
find /var -type f -name "*.iso" -exec cp {} "${OUT_DIR}/" \; || true
ls -lh "${OUT_DIR}" || true
