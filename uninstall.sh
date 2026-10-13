#!/bin/sh
# Remove o constancia. Seus dados em ~/.local/share/constancia são mantidos.
systemctl --user disable --now constancia.timer >/dev/null 2>&1
rm -f "$HOME/.config/systemd/user/constancia.service" "$HOME/.config/systemd/user/constancia.timer"
systemctl --user daemon-reload >/dev/null 2>&1
for pasta in "$HOME/.local/share/applications" "$HOME/.config/autostart"; do
  rm -f "$pasta/io.github.hendesson.constancia.desktop" "$pasta/constancia.desktop"
done
gnome-extensions disable constancia@hendesson.github.io >/dev/null 2>&1
rm -rf "$HOME/.local/share/gnome-shell/extensions/constancia@hendesson.github.io"
rm -f "$HOME/.local/share/icons/hicolor/scalable/apps/io.github.hendesson.constancia.svg"
rm -f "$HOME/.local/bin/constancia"
echo "✔ removido (dados mantidos em ~/.local/share/constancia)"
