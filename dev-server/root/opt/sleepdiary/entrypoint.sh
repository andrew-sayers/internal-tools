#!/bin/sh

# the scrollback=0 below currently does nothing useful,
# but in future will hopefully disable the scrollbar:
# https://github.com/xtermjs/xterm.js/pull/3398/commits/dab73aa26355d8897968bffe3fc3366c2ca80a28
start-stop-daemon \
    --chdir /app \
    --start \
    --background \
    --exec /opt/sleepdiary/ttyd \
    -- \
    --readonly \
    -i /opt/sleepdiary/web-ttys/tmux.sock \
    -t fontSize=10 \
    -t 'theme={"foreground":"black","background":"white"}' \
    tmux attach -tconsole

start-stop-daemon \
    --chdir /app \
    --start \
    --background \
    --exec /opt/sleepdiary/ttyd \
    -- \
    --readonly \
    --url-arg \
    -i /opt/sleepdiary/web-ttys/rebuild-and-test.sock \
    -t 'theme={"foreground":"black","background":"white"}' \
    -t fontSize=10 \
    /opt/sleepdiary/rebuild-and-test.sh

/etc/init.d/nginx start

start-stop-daemon \
    --chdir /opt/sleepdiary \
    --start \
    --background \
    --exec /opt/sleepdiary/markdown-server.mjs

# Used by Vue apps:
export VUE_APP_PUBLIC_PATH="/dashboard"
export VUE_APP_SCRIPT_URL="http://localhost:8080/"
export VUE_APP_DEV_SERVER="localhost:8081"

#
# Configure tmux
# based on https://stackoverflow.com/questions/57429593/create-new-pane-from-tmux-command-line
#

tmux start-server

N=0
for DIR in /app/*
do
    if [ -x "$DIR/bin/run.sh" ]
    then
        COMMAND="cd '$DIR' && ./bin/run.sh serve"
        case "$N" in
            0)
                tmux new-session -d -s console -n Shell1 -d "$COMMAND"
                N=2
                ;;

            4)
                tmux split-window -t console:0 "$COMMAND"
                tmux select-layout -t console:0 tiled
                N=1
                ;;

            *)
                tmux split-window -t console:0 "$COMMAND"
                N="$((N+1))"
                ;;
        esac
    fi
done

tmux split-window -t console:0 "echo 'dev-server: watching /var/log'; exec tail -n 0 -f $( find /var/log -type f -name \*log )"
[ "$N" = 4 ] && tmux select-layout -t console:0 tiled
tmux split-window -t console:0 "tmux bind-key r respawn-pane ; cat /opt/sleepdiary/help.txt ; exec /bin/bash -l"
tmux select-layout -t console:0 tiled
tmux set-option -t console:0 status off
tmux set-option -t console:0 remain-on-exit on

#tmux attach -tconsole

# wait for all ttyd sockets to come up:
while [ $( ls /opt/sleepdiary/web-ttys/*.sock | wc -l ) -lt 2 ]
do sleep 1
done
# Fix socket permissions:
chmod 666 /opt/sleepdiary/web-ttys/*.sock

sleep infinity