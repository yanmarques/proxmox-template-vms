# shellcheck shell=bash

run_test() {
    source ./tests/unix/linux/functions
    setup

    $1

    teardown
}