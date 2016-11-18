function run_java() {
    declare timeout="$1" pidfile="$2" command="$3"

    eval "$command &"
    echo "$(date -Iseconds): Starting application with pid $!.  Will wait $timeout seconds for process to start."
    start=$SECONDS
    while kill -0 $! >/dev/null 2>&1
    do
        duration=$(( SECONDS - start ))
        if [ -f $pidfile ] ; then
            wait $!
            EXIT_STATUS=$?
            echo "$(date -Iseconds): Pid $! exited with status $EXIT_STATUS"
            exit $EXIT_STATUS
        fi

        if [ $duration -gt $timeout ]; then
            echo "$(date -Iseconds): Forcefully killing $! because it failed to write pid file after ${timeout}s."
            kill -9 $! > /dev/null 2>&1
            exit 1
        fi

        sleep 2
    done
}