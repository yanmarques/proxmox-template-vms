#!/bin/bash

# shellcheck source=/dev/null
. ./tests/unix/linux/functions

with_raw_disk_formated() {
    format_disk_when_raw "$test_disk" "$test_disk" \
        -F -E offset="$default_part_offset" 2> /dev/null
}

format_an_already_formated_disk_does_nothing() {
    with_raw_disk_formated
    
    loop_mount "$test_disk" "$rw_dir"

    # artifact to test
    touch "$rw_dir"/templated-test-file

    umount "$rw_dir"

    # call formatting again
    with_raw_disk_formated

    loop_mount "$test_disk" "$rw_dir"

    [ -e "$rw_dir"/templated-test-file ]
}