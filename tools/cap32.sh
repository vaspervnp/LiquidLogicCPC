#!/bin/sh
# Caprice32 (snap) με κανονικά ορίσματα.
# Ο caprice32.launcher του snap κρατάει μόνο τα δύο πρώτα ορίσματα ως
# δισκέτες και πετάει τα -O/-a, οπότε καλούμε το cap32 απευθείας μέσα
# στο περιβάλλον του snap, με το cfg που φτιάχνει ο launcher.
#   tools/cap32.sh [επιλογές cap32] αρχείο.dsk|.sna
# Τα αρχεία πρέπει να είναι κάτω από το $HOME (strict confinement).
[ -n "$CAP32_IN_SNAP" ] || exec env CAP32_IN_SNAP=1 snap run --shell caprice32.launcher -c '"$0" "$@"' "$(realpath "$0")" "$@"
exec "$SNAP/usr/bin/cap32" --cfg_file="$SNAP_USER_DATA/etc/cap32.cfg" "$@"
