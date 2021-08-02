# Utilities used by build scripts

if type cmd_run >/dev/null 2>&1
then
    HAS_RUN=1
else
    HAS_RUN=
fi

if type cmd_upgrade >/dev/null 2>&1
then
    HAS_UPGRADE=1
else
    HAS_UPGRADE=
fi

WARNED=
warning() {
    echo
    echo ^^^ "$1"
    shift
    for LINE in "$@"
    do echo "$LINE"
    done
    echo
    echo
    WARNED=1
}

check_errors() {
    if [ "$RESULT" != 0 ]
    then
        echo
        echo "Please fix the above errors"
        exit "$RESULT"
    fi
    if [ "$WARNED" != "" ]
    then
        echo
        echo "Please fix the above errors"
        exit "$WARNED"
    fi
}

help_message() {
    USAGE="test | build | merge-and-push"
    [ -n "$HAS_RUN"     ] && USAGE="$USAGE | run"
    [ -n "$HAS_UPGRADE" ] && USAGE="$USAGE | upgrade"
    USAGE_PORT=""     ; [ -n "NEEDS_PORT" ] && PORT_USAGE=" -p some_port:8080"
    cat <<EOF
Sleepdiary $SLEEPDIARY_NAME builder

Usage:
       docker run --rm -it -v /path/to/sleepdiary/$SLEEPDIARY_NAME:/app$PORT_USAGE sleepdiary/builder [ $USAGE ] [ --force ]

Options:
  --force        run the command even if everything is already up-to-date
  test           (default) build and run tests
  build          build without running tests
  merge-and-push build, run tests, and push to the upstream repository
EOF
    [ -n "$HAS_RUN"     ] && echo "  run            run a development environment"
    [ -n "$HAS_UPGRADE" ] && echo "  upgrade        upgrade all dependencies"
    cat <<EOF

License: https://github.com/sleepdiary/$SLEEPDIARY_NAME/blob/main/LICENSE
EOF
}

FORCE=
for ARG
do
    shift
    case "$ARG" in
        -f|--f|--fo|--for|--forc|--force)
            FORCE=1
            ;;
        *)
            set -- "$@" "$ARG"
            ;;
    esac
done

case "$1" in

    test|"")

        FORCE=1

        cmd_build
        RESULT="$?"
        check_errors

        cmd_test
        RESULT="$?"
        check_errors
        echo

        git diff --exit-code || {
            git status
            echo "Please commit the above changes"
            exit 2
        }

        if [ $( git rev-list --count HEAD..@{u}) != 0 ]
        then
            echo
            echo "Please pull or rebase upstream changes"
            exit 2
        fi

        # Make sure we're going to push what we expected to:
        git diff @{u}
        echo
        git log --oneline --graph @{u}...HEAD

        echo
        echo "Please review the above changes, then do: git push"
        exit 0

        ;;

    build)
        cmd_build
        exit "$?"
    ;;

    merge-and-push)

        set -v # verbose mode - print commands to stderr
        set -e # exit if any of the commands below return non-zero

        #
        # Check if there are changes to commit
        #

        if ! git diff --quiet
        then
            git diff
            echo "Please commit all changes"
            exit 2
        fi

        #
        # Check if there's anything to do
        #

        if ! git rev-list HEAD..origin/main | grep -q .
        then
            echo "'main' has already been merged - stopping"
            exit 0
        fi

        #
        # Merge changes from main
        #

        git merge --strategy-option=theirs --no-edit origin/main

        #
        # Run the build itself
        #

        cmd_build
        cmd_test

        #
        # Add/commit/push changes
        #

        git add .
        if git diff --quiet HEAD
        then echo "No changes to commit"
        else git commit -a -m "Build updates from main branch"
        fi
        git push

        ;;

    run)
        if [ -z "$HAS_RUN" ]
        then
            help_message
            exit 2
        else
            cmd_run
            exit "$?"
        fi
        ;;

    upgrade)
        if [ -z "$HAS_UPGRADE" ]
        then
            help_message
            exit 2
        else
            cmd_upgrade
            exit "$?"
        fi
        ;;

    h|help|-h|--h|--he|--hel|--help)
        help_message
        exit 0
        ;;

    *)
        help_message
        exit 2
        ;;

esac
