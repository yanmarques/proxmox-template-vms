#!/bin/bash

# shellcheck source=/dev/null
. ./tests/unix/linux/functions

start() {
    # artifact to test
    touch "$skel_dir"/testing-templated

    start_disk "$test_disk"

    umount "$rw_dir"

    # re-mount disk to be sure
    register_tmp_dir
    local tmp_dir="$(last_tmp_dir)"
    loop_mount "$test_disk" "$tmp_dir"

    local expected_dirs=('config' 'binds' 'home')
    for directory in "${expected_dirs[@]}"; do
        test -d "$tmp_dir/$directory"
    done

    test -e "$tmp_dir/$test_home/testing-templated"
}

with_raw_disk_formated() {
    format_disk_when_raw "$test_disk" "$test_disk" \
        -F -E offset="$default_part_offset"
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