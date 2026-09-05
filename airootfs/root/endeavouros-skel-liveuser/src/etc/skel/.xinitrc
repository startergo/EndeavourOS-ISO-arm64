#!/bin/sh

# Force EGL and Qt to X11/XCB
export EGL_PLATFORM=x11
export QT_QPA_PLATFORM=xcb

# needed for plasma x11 session
export XDG_SESSION_TYPE=x11
export DESKTOP_SESSION=plasma
export XDG_CURRENT_DESKTOP=KDE
export XDG_SESSION_DESKTOP=KDE
export KDE_FULL_SESSION=true

if command -v spice-vdagent >/dev/null 2>&1; then
	spice-vdagent &
fi

# Start Plasma session on X11
exec startplasma-x11
