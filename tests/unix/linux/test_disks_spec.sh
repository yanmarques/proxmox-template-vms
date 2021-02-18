# shellcheck shell=bash

Include ./tests/unix/linux/functions

Describe "disks_counter()"
    It "1 scsi disk"
        Mock fdisk
            echo "Disk /dev/sda"
        End

        When call disks_counter
        The output should eq "1"
    End

    It "3 ide disks"
        Mock fdisk
            echo "Disk /dev/hda"
            echo "Disk /dev/hdb"
            echo "Disk /dev/hdc"
        End

        When call disks_counter
        The output should eq "3"
    End

    It "1 scsi disk and 1 ide disk"
        Mock fdisk
            echo "Disk /dev/sda"
            echo "Disk /dev/hdc"
        End

        When call disks_counter
        The output should eq "2"
    End
End

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

Describe "start_from_partition()" current:test
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
