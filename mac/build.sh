#!/usr/bin/env bash
# Native macOS (Apple Silicon or Intel) build of XPilot 4.5.5 + Xpilot-AI.
#
# Builds from the XPilot 4.5.5 tarball plus the AI sources in ../source and
# ../library, and installs everything under mac/:
#   mac/bin/          xpilot, xpilots, xp-mapedit, xp-replay, AI libraries
#   mac/lib/xpilot/   server data (defaults, robots, maps, textures)
#
# Requirements: Xcode Command Line Tools, Homebrew libx11 and libxext
# (brew install libx11 libxext). Java and Python are optional.
#
# Usage: mac/build.sh            (PYTHON=python3.14 mac/build.sh to pick a Python)
set -euo pipefail

MAC_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$MAC_DIR")"
BUILD_DIR="$MAC_DIR/build"
BIN_DIR="$MAC_DIR/bin"
LIB_DIR="$MAC_DIR/lib/xpilot"
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
PYTHON="${PYTHON:-python3}"

TARBALL_URL="https://gitlab.com/xpilot-ai/xpilot-ai/-/raw/master/archives/xpilot-4.5.5.tar.bz2"
TARBALL_SHA256="5e40424d093c8b712170a5dff3396df63302775f42da829b8832840f359cd92a"
TARBALL="$BUILD_DIR/xpilot-4.5.5.tar.bz2"
SRC="$BUILD_DIR/xpilot-4.5.5"

CC="${CC:-clang}"
# -D_FORTIFY_SOURCE=0: macOS defines strlcpy/strlcat as fortify macros, which
# breaks XPilot's own prototypes for them.
CFLAGS="-O2 -fPIC -D_FORTIFY_SOURCE=0 -DWINDOWSCALING -I$BREW_PREFIX/include \
  -Wno-deprecated-non-prototype -Wno-implicit-const-int-float-conversion"
# The AI libraries (cAI.c, pyAI.c, javaAI.c) call some int functions before
# declaring them and return values from void functions. Each such call was
# checked to match its definition, so keep these as warnings, not errors.
AI_CFLAGS="$CFLAGS -Wno-error=implicit-function-declaration \
  -Wno-error=int-conversion -Wno-error=return-mismatch"
XLIBS="-L$BREW_PREFIX/lib -lX11 -lm"

log() { printf '\n==> %s\n' "$*"; }

[ -f "$BREW_PREFIX/include/X11/Xlib.h" ] || {
  echo "X11 headers not found. Run: brew install libx11 libxext" >&2; exit 1; }

# --- Fetch and prepare XPilot 4.5.5 -----------------------------------------
mkdir -p "$BUILD_DIR"
if [ ! -f "$TARBALL" ]; then
  log "Downloading XPilot 4.5.5"
  curl -fL -o "$TARBALL" "$TARBALL_URL"
fi
echo "$TARBALL_SHA256  $TARBALL" | shasum -a 256 -c -

log "Unpacking"
rm -rf "$SRC"
tar xjf "$TARBALL" -C "$BUILD_DIR"
# getline() clashes with the libc function of the same name.
LC_ALL=C find "$SRC" -type f -name '*.[ch]' -exec sed -i '' 's/getline/xpgetline/g' {} +

# --- Common library ---------------------------------------------------------
log "Building libxpcommon"
cd "$SRC/src/common"
# strlcpy.c is left out: macOS libc already provides strlcpy and strlcat.
COMMON="checknames config error list math net portability randommt shipshape
  socklib strcasecmp strdup xpmemory"
for f in $COMMON; do
  $CC $CFLAGS -I. -I../../lib -DLIBDIR="\"$LIB_DIR/\"" -c $f.c -o $f.o
done
ar rcs libxpcommon.a $(for f in $COMMON; do echo $f.o; done)
COMMON_LIB="$SRC/src/common/libxpcommon.a"

# --- Server (Xpilot-AI version: cmdlineAI.c, playerAI.c) --------------------
log "Building xpilots"
cd "$SRC/src/server"
cp "$REPO_DIR/source/globalAI.h" "$REPO_DIR/source/cmdlineAI.c" "$REPO_DIR/source/playerAI.c" .
SERVER="alliance asteroid cannon cell cmdlineAI collision command contact event
  fileparser frame id item laser map metaserver netserver object objpos option
  parser play playerAI robot robotdef rules saudio sched score server ship shot
  showtime stratbot tuner update walls wildmap"
for f in $SERVER; do
  $CC $CFLAGS -I../common -I../lib -c $f.c -o $f.o
done
$CC -o xpilots $(for f in $SERVER; do echo $f.o; done) "$COMMON_LIB" -lm

# --- Client -----------------------------------------------------------------
log "Building xpilot client"
cd "$SRC/src/client"
cp "$REPO_DIR"/source/{clientAI.c,clientAI.h,defaultAI.c,paintdataAI.c,painthudAI.c,xpilotAI.c} .
# Objects shared by the stock client and every AI library.
CLIENT_SHARED="about blockbitmaps caudio colors configure datagram dbuff gfx2d
  gfx3d guimap guiobjects join netclient paint paintmap paintobjects paintradar
  query record sim syslimit talk talkmacros textinterface texture usleep welcome
  widget xeventhandlers xevent xinit xpmread"
CLIENT_STOCK="client default paintdata painthud xpilot"
CLIENT_AI="clientAI defaultAI paintdataAI painthudAI xpilotAI"
for f in $CLIENT_SHARED $CLIENT_STOCK $CLIENT_AI; do
  $CC $CFLAGS -I../common -I../../lib -c $f.c -o $f.o
done
objs() { for f in "$@"; do echo "$f.o"; done; }
$CC -o xpilot $(objs $CLIENT_SHARED $CLIENT_STOCK) "$COMMON_LIB" $XLIBS
AI_OBJS="$(objs $CLIENT_SHARED $CLIENT_AI)"

mkdir -p "$BIN_DIR"
cp "$SRC/src/server/xpilots" "$SRC/src/client/xpilot" "$BIN_DIR/"

# --- AI libraries -----------------------------------------------------------
log "Building C AI library (libcAI.dylib)"
cp "$REPO_DIR/library/c/cAI.c" "$REPO_DIR/library/c/cAI.h" .
$CC $AI_CFLAGS -I../common -I../../lib -c cAI.c -o cAI.o
$CC -dynamiclib -install_name @rpath/libcAI.dylib -o libcAI.dylib \
  $AI_OBJS cAI.o "$COMMON_LIB" $XLIBS
cp libcAI.dylib cAI.h "$BIN_DIR/"

if "$PYTHON" -c 'import sysconfig' 2>/dev/null; then
  # The Command Line Tools python3 reports a header path that does not exist,
  # so fall back to the headers inside its framework.
  PY_INC="$("$PYTHON" - <<'PY'
import os, sys, sysconfig
cands = [sysconfig.get_paths()["include"], sysconfig.get_config_var("INCLUDEPY") or "",
         os.path.join(sys.prefix, "Headers"),
         os.path.join(sys.prefix, "include", "python%d.%d" % sys.version_info[:2])]
print(next((c for c in cands if os.path.isfile(os.path.join(c, "Python.h"))), ""))
PY
)"
  PY_SUFFIX="$("$PYTHON" -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))')"
  if [ -n "$PY_INC" ]; then
    log "Building Python AI module (libpyAI$PY_SUFFIX)"
    cp "$REPO_DIR/library/python/pyAI.c" .
    $CC $AI_CFLAGS -I../common -I../../lib -I"$PY_INC" -c pyAI.c -o pyAI.o
    # Python symbols resolve against the running interpreter at import time.
    $CC -bundle -undefined dynamic_lookup -o "libpyAI$PY_SUFFIX" \
      $AI_OBJS pyAI.o "$COMMON_LIB" $XLIBS
    cp "libpyAI$PY_SUFFIX" "$BIN_DIR/"
  else
    log "Skipping Python: no Python.h for $PYTHON"
  fi
else
  log "Skipping Python: $PYTHON not found"
fi

JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home 2>/dev/null || true)}"
if [ -n "$JAVA_HOME" ] && [ -f "$JAVA_HOME/include/jni.h" ]; then
  log "Building Java AI library (libjavaAI.dylib)"
  cp "$REPO_DIR/library/java/javaAI.java" "$REPO_DIR/library/c/javaAI.c" .
  "$JAVA_HOME/bin/javac" -h . javaAI.java
  $CC $AI_CFLAGS -I../common -I../../lib -I"$JAVA_HOME/include" \
    -I"$JAVA_HOME/include/darwin" -c javaAI.c -o javaAI.o
  $CC -dynamiclib -o libjavaAI.dylib $AI_OBJS javaAI.o "$COMMON_LIB" $XLIBS
  cp libjavaAI.dylib javaAI.java javaAI.class "$BIN_DIR/"
else
  log "Skipping Java: no JDK found"
fi

# --- Map editor and replay tool ---------------------------------------------
log "Building xp-mapedit"
cd "$SRC/src/mapedit"
MAPEDIT="main expose events tools file round help grow forms T_Toolkit T_Form
  T_Popup T_Handler"
for f in $MAPEDIT; do
  $CC $CFLAGS -I../common -DLIBDIR="\"$LIB_DIR/\"" -c $f.c -o $f.o
done
$CC -o xp-mapedit $(objs $MAPEDIT) "$COMMON_LIB" $XLIBS
cp xp-mapedit "$BIN_DIR/"

log "Building xp-replay"
cd "$SRC/src/replay"
for f in xp-replay buttons; do
  $CC $CFLAGS -I../common -I../client -c $f.c -o $f.o
done
$CC -o xp-replay xp-replay.o buttons.o "$COMMON_LIB" $XLIBS
cp xp-replay "$BIN_DIR/"

# --- Server data ------------------------------------------------------------
log "Installing server data into $LIB_DIR"
mkdir -p "$LIB_DIR/maps"
cp "$SRC/lib/defaults" "$SRC/lib/robots" "$SRC/lib/password" "$LIB_DIR/"
cp -R "$SRC/lib/textures" "$LIB_DIR/"
cp "$SRC"/lib/maps/*.xp "$LIB_DIR/maps/"
cp "$REPO_DIR"/maps/*.xp "$LIB_DIR/maps/"

# --- Make the AI libraries loadable from bots/ ------------------------------
# Copy the Mac libraries into every bots/ folder holding a bot, so bots run
# from their own folder. Some folders also hold the Linux libpyAI.so: Python on
# macOS tries the .cpython-XY-darwin.so suffix before plain .so, and Java looks
# for .dylib, so the Mac libraries sit beside the Linux ones.
log "Copying AI libraries into bot folders under bots/"
PY_MODULE="$(ls "$BIN_DIR"/libpyAI*-darwin.so 2>/dev/null | head -1)"
grep -rlE --include='*.py' '^import libpyAI' "$REPO_DIR/bots" | xargs -n1 dirname | sort -u |
  while read -r dir; do
    [ -n "$PY_MODULE" ] && cp "$PY_MODULE" "$dir/"
    echo "  python: ${dir#$REPO_DIR/}"
  done
grep -rlE --include='*.java' 'extends javaAI' "$REPO_DIR/bots" | xargs -n1 dirname | sort -u |
  while read -r dir; do
    [ -f "$BIN_DIR/libjavaAI.dylib" ] && cp "$BIN_DIR/libjavaAI.dylib" "$dir/"
    echo "  java:   ${dir#$REPO_DIR/}"
  done

log "Done. Binaries are in $BIN_DIR"
