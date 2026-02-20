#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

if [ -z "$DISPLAY" ] && [ "$(tty 2>/dev/null)" = "/dev/tty1" ]; then
  if command -v startx >/dev/null 2>&1; then
    startx && exit 0
  fi
  if command -v startplasma-wayland >/dev/null 2>&1; then
    exec dbus-run-session startplasma-wayland
  fi
fi

