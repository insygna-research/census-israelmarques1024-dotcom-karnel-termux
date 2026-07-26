#!/data/data/com.termux/files/usr/bin/env bash
ZORK_DIR="$HOME/.local/share/karnel-data/zork"
if [ ! -f "$ZORK_DIR/zork1.dat" ]; then
  mkdir -p "$ZORK_DIR"
  echo "Baixando Zork I..."
  curl -sL "https://www.infocom-if.org/downloads/zork1.zip" -o /tmp/zork1.zip
  unzip -o /tmp/zork1.zip -d "$ZORK_DIR" 2>/dev/null
  rm -f /tmp/zork1.zip
fi
exec frotz "$ZORK_DIR/zork1.dat" "$@"
