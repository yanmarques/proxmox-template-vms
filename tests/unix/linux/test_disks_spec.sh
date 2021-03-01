# shellcheck shell=bash

Include ./tests/unix/linux/functions

Describe "prepare_disk_when_raw()"
    It 'create filesystem'
        has_filesystem() {
            dumpe2fs "$1" > /dev/null 2>&1
        }

        # shellcheck disable=SC2154
        When call with_raw_disk_formated
        The status should eq 0
        The output should not include failed

        # shellcheck disable=SC2154
        Assert has_filesystem "$test_disk"
    End

    It 'not raw disk after preparation'
        # shellcheck disable=SC2154
        When call with_raw_disk_formated
        The status should eq 0
        The output should not include failed
        The variable test_disk should satisfy is_disk
    End

    Context 'when not raw'
        Before "with_raw_disk_formated"

        It "does not format the disk"
            Mock mkfs.ext4
                exit 255
            End

            When call with_raw_disk_formated
            The status should eq 0
            The entire output should eq ''
        End
    End

    It 'fails with fs error code'
        # fake a mkfs error
        Mock mkfs.ext4
            exit 1
        End

        When call with_raw_disk_formated

        # shellcheck disable=SC2154
        The status should eq "$file_system_err"
        The stderr should include failed
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
        It "formats and mounts"
            When call start_disk "$test_disk"
            The status should eq 0
            The output should not include failed
            The variable rw_dir should satisfy mounted
        End

        It "fails with mount status code"
            # fake mount error
            mount() {
                return 1
            }

            When call start_disk "$test_disk"
            The output should not include failed
            The stderr should include failed
            
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

Describe "start_disk_from_partition()"
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

        When call start_disk_from_partition some-uuid
        The status should eq 123
        The variable device should eq /dev/templated-test-0
        The variable partition should eq /dev/templated-test-1
    End
End
