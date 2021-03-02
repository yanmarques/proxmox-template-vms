# shellcheck shell=bash

Include ./tests/unix/linux/functions

Describe "make_filesystem()"
    It 'ensure has filesystem'
        has_filesystem() {
            dumpe2fs "$1" > /dev/null 2>&1
        }

        # shellcheck disable=SC2154
        When call make_filesystem "$test_disk"
        The status should eq 0
        The output should not include failed

        # shellcheck disable=SC2154
        Assert has_filesystem "$test_disk"
    End
End

Describe "is_raw_disk()"
    It "recognizes dummy created disk as raw"
        # shellcheck disable=SC2154
        When call is_raw_disk "$test_disk"
        The status should be success
    End

    Context 'when disk is not raw'
        Before "with_raw_disk_formated"

        It "recognizes dummy formated disk as not raw"
            When call is_raw_disk "$test_disk"
            The status should be failure
        End
    End
End

Describe "mount_strategy()"
    
    It "mounts disks when source is a block device"
        mount() {
            # shellcheck disable=SC2154
            [ "$1" == "$test_disk" ] && [ "$2" == "$rw_dir" ]
        }

        # shellcheck disable=SC2154
        When call mount_strategy "$test_disk" "$rw_dir" --force-disk
        The status should be success
    End

    It "bind mounts when source is not a block device"
        mount() {
            [ "$1" == --bind ]
        }

        # shellcheck disable=SC2154
        When call mount_strategy "$test_disk" "$rw_dir"
        The status should be success
    End

    It "creates mountpoint file when missing"
        mount() {
            :
        }

        # shellcheck disable=SC2154
        When call mount_strategy "$test_disk" "$rw_dir/testing/dummy"

        The value "$rw_dir/testing/dummy" should be a file
    End

    It "creates mountpoint directory when missing"
        mount() {
            :
        }

        # shellcheck disable=SC2154
        When call mount_strategy "$rw_dir" "$rw_dir/testing/dummy"

        The value "$rw_dir/testing/dummy" should be a directory
    End

    Context
        cleanup() {
            umount "$rw_dir"/*
        }
        
        After "cleanup"

        It "creates mountpoint from file"
            # shellcheck disable=SC2154
            When call mount_strategy "$test_disk" "$rw_dir/dummy"

            Assert same_contents "$test_disk" "$rw_dir/dummy"
        End
    End

End
