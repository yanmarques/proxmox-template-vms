# shellcheck shell=bash

Describe "populate_home_dir()"
    Context
        touch_artifact() {
            # shellcheck disable=SC2154
            touch "$skel_dir"/dummy-file
        }

        Before "touch_artifact"

        It "initialize home dir from skel and fix permissions"
            When call populate_home_dir
            The status should be success

            # shellcheck disable=SC2154
            The value "$(rw_base_home)"/"$user"/dummy-file should be a file
            The output should not include failed

            Assert is_owner "$user" "$(rw_base_home)"/"$user"
            Assert is_owner "$user" "$(rw_base_home)"/"$user"/dummy-file
        End
    End
End

Describe "setup_vm_user_data()"
    It "creates basic structure"
        setup_vm_user_data_with_fake_home() {
            # shellcheck disable=SC2034
            base_home_dir=/home
            setup_vm_user_data
        }

        When call setup_vm_user_data_with_fake_home
        The entire output should not include failed
        Assert has_default_rw_files
    End

    It "keeps already present config files"
        make_two_setups() {
            setup_vm_user_data

            # shellcheck disable=SC2154
            echo testing > "$rc_config"

            # shellcheck disable=SC2154
            echo testing > "$binds_config"
            
            setup_vm_user_data
        }

        When call make_two_setups
        The entire output should not include failed
        Assert same_contents "$rc_config" "$binds_config"
    End

    It "only calls hook when home directory is missing"
        # ensure it does not gets here
        post_home_dir_populated() {
            return 1
        }

        setup_with_home_dir_present() {
            mkdir -p "$(rw_base_home)"
            setup_vm_user_data
        }

        When call setup_with_home_dir_present
        The status should be success
        The entire output should not include failed
    End
End

Describe "ensure_formated_and_mounted()"
    unset TEMPLATED_DEV

    start_disk_from_partition() {
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

    It "ignore many disks when has partition"
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

Describe "mount_host_data()"
    It "calls mount with default host cdrom as read-only"
        mount() {
            echo "$1"
        }

        find_device_by_uuid() {
            echo /foo/baz
        }

        When call mount_host_data
        The status should be success
        The output should start with /foo/baz 
    End
End

Describe "bind_files()" current
    create_dirs() {
        load_runtime_vars

        # create a fake home
        mkdir -p "$(rw_base_home)"
        setup_vm_user_data
    }

    # sanity check
    mount_strategy() {
        :
    }

    Before create_dirs

    It "calls mount with the correct target file"
        mount_strategy() {
            echo "$2"
        }

        call_bind_files() {
            # shellcheck disable=SC2154
            mkdir -p "$binds_dir"/foo/bar
            touch "$binds_dir"/foo/bar/baz

            bind_files "$binds_dir"
        }

        When call call_bind_files
        The status should be success
        The output should start with /foo/bar/baz
    End

    It "calls mount with empty directory when is a bind dir"
        mount_strategy() {
            echo "$2"
        }

        call_bind_files() {
            expected_dir="$binds_dir"/foo/bar
            mkdir -p "$expected_dir"

            # register as bind dir
            # shellcheck disable=SC2154
            echo /foo/bar >> "$binds_config"
            bind_files "$binds_dir"
        }

        When call call_bind_files
        The status should be success
        The output should start with /foo/bar
    End

    It "calls mount with non-empty directory when is a bind dir"
        mount_strategy() {
            echo "$2"
        }

        call_bind_files() {
            expected_dir="$binds_dir"/foo/bar
            mkdir -p "$expected_dir"/bazz

            # register as bind dir
            # shellcheck disable=SC2154
            echo /foo/bar >> "$binds_config"
            bind_files "$binds_dir"
        }

        When call call_bind_files
        The status should be success
        The output should start with /foo/bar
    End

    It "fails with empty directory"
        call_bind_files() {
            mkdir -p "$binds_dir"/foo/

            bind_files "$binds_dir"/foo/
        }

        When call call_bind_files
        The status should eq 2
    End

    It "backup original file when present"
        mount_strategy() {
            return 0
        }

        call_bind_files() {
            register_tmp_dir
            relative_path="$(last_tmp_dir)"/foo/bar
            mkdir -p "$relative_path"
            %preserve relative_path

            # create bind directory
            expected_dir="$binds_dir""$relative_path"
            mkdir -p "$expected_dir"

            # create file to be bound
            touch "$expected_dir"/foo

            # create original file
            touch "$relative_path"/foo

            bind_files "$binds_dir"
        }

        backup_foo_file() {
            [ -f "$relative_path"/foo.old ]
        }

        When call call_bind_files
        The output should not include failed
        Assert backup_foo_file
    End
End