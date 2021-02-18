# shellcheck shell=bash

Include ./tests/unix/linux/functions

Describe "format_disk_when_raw()"
    It 'formats the disk'
        When call with_raw_disk_formated
        The status should eq 0
        The output should not include failed
        The variable test_disk should satisfy is_disk
    End

    Context 'when not raw'
        Before "with_raw_disk_formated"

        It "does not format the disk"
            When call with_raw_disk_formated
            The entire output should eq ''
        End
    End

    It 'fails with format error code'
        # fake a sfdisk error 
        sfdisk() {
            return 1
        }

        When call with_raw_disk_formated

        # shellcheck disable=SC2154
        The status should eq "$format_disk_err"
    End

    It 'fails with fs error code'
        # fake a mkfs error
        Mock mkfs.ext4
            exit 1
        End

        When call with_raw_disk_formated

        # shellcheck disable=SC2154
        The status should eq "$file_system_err"
        The output should not include failed
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


Describe "start_disk()" mount_mock
    Context "when format and mount a dummy disk"
        setup_rw_device() {
            # shellcheck disable=SC2154
            start_disk "$test_disk" -B "$test_disk" \
                --format-opts "$default_mkfs_opts" \
                --mount-opts "$default_loop_mount_opts" > /dev/null 2>&1
        }

        It "formats and mounts"
            When call setup_rw_device
            The variable rw_dir should satisfy mounted
        End

        It "fails with mount status code"
            # fake mount error
            mount() {
                return 1
            }

            When call setup_rw_device
            
            # shellcheck disable=SC2154
            The status should eq "$mount_err"
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

Describe "start_from_partition()"
    It "find the device informations from uuid"
        blkid() {
            echo /dev/templated-test-1           
        }

        lsblk() {
            if [ "--output UUID,PTUUID" == "$*" ]; then
                echo "some-uuid some-ptuuid"
            else
                echo "some-ptuuid /dev/templated-test-0"
            fi
        }

        start_disk() {
            # shellcheck disable=SC2034
            device="$1"

            # ignore the '-B'
            shift

            # shellcheck disable=SC2034
            partition="$2"

            %preserve device partition

            return 123
        }

        When call start_from_partition some-uuid
        The status should eq 123
        The variable device should eq /dev/templated-test-0
        The variable partition should eq /dev/templated-test-1
    End
End

Describe "ensure_formated_and_mounted()"
    unset TEMPLATED_DEV

    start_from_partition() {
        echo "$@"
        return 11
    }

    start_disk() {
        echo "$@"
        return 22
    }

    detect_partition() {
        :
    }

    detect_raw_disk() {
        :
    }

    Context "fails when"
        # sanity check
        start_disk() {
            :
        }

        It "more than 1 disk and partition"
            detect_partition() {
                echo 1
                echo 2
            }

            detect_raw_disk() {
                echo 3
                echo 4
            }

            When call ensure_formated_and_mounted
            The status should eq 5
            The length of output should satisfy testit -gt 0
            The length of stderr should satisfy testit -gt 0
        End

        It "any detected device"
            When call ensure_formated_and_mounted
            The status should eq 5
            The stderr should include "any raw disk or partition available"
        End

        It "only detected more than 1 raw disks"
            detect_raw_disk() {
                echo 3
                echo 4
            }

            When call ensure_formated_and_mounted
            The status should eq 5
            The length of output should satisfy testit -gt 0
            The length of stderr should satisfy testit -gt 0
        End

        It "only detected more than 1 partitions"
            detect_partition() {
                echo 3
                echo 4
            }

            When call ensure_formated_and_mounted
            The status should eq 5
            The length of output should satisfy testit -gt 0
            The length of stderr should satisfy testit -gt 0
        End
    End

    It "calls start_from_partition() with uuid"
        detect_partition() {
            echo some-uuid
        }

        When call ensure_formated_and_mounted
        The status should eq 11
        The output should eq "some-uuid"
    End

    It "calls start_disk() with raw device"
        detect_raw_disk() {
            echo test-device
        }

        When call ensure_formated_and_mounted
        The status should eq 22
        The output should eq "test-device -B test-device1"
    End

    It "call partition to format when raw disk also present"
        detect_partition() {
            echo some-uuid
        }

        detect_raw_disk() {
            echo ignored-device
        }

        When call ensure_formated_and_mounted
        The status should eq 11
        The output should eq "some-uuid"
    End

    It "ignore many partitions when has raw disk"
        detect_partition() {
            echo ignored-part
            echo ignored-part
        }

        detect_raw_disk() {
            echo test-device
        }

        When call ensure_formated_and_mounted
        The status should eq 22
        The output should eq "test-device -B test-device1"
    End

    It "ignore many disks when has partition" current:test
        detect_partition() {
            echo test-partition
        }

        detect_raw_disk() {
            echo ignored-device
            echo ignored-device
        }

        When call ensure_formated_and_mounted
        The status should eq 11
        The output should eq "test-partition"
    End

    It "calls start_disk() from environment"
        start_with_templated_dev() {
            # shellcheck disable=SC2034
            TEMPLATED_DEV=templated-test

            ensure_formated_and_mounted
        }

        When call start_with_templated_dev
        The status should eq 22             
        The output should eq "templated-test"

    End
End