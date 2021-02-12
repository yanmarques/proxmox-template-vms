# shellcheck shell=bash

Include ./tests/unix/linux/functions

BeforeEach "setup"
AfterEach "teardown"

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
            The status should eq 1
        End
    End
End

Describe "is_raw_disk()"
    It "recognizes dummy created disk as raw"
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

