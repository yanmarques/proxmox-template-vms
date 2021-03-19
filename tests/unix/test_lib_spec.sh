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

    Context
        touch_artifact_inner_directory() {
            mkdir "$skel_dir"/foo
            touch "$skel_dir"/foo/bar
        }

        Before "touch_artifact_inner_directory"

        It "ensure copy directories recursively"
            When call populate_home_dir
            The status should be success

            # shellcheck disable=SC2154
            The value "$(rw_base_home)"/"$user"/foo/bar should be a file
            The output should not include failed
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

    find_device_by_uuid() {
        echo "$@"
    }

    start_disk() {
        echo "$@"
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

    It "calls start_disk() with device from find_device_by_uuid"
        detect_partition() {
            echo some-uuid
        }

        When call ensure_formated_and_mounted
        The output should eq "some-uuid"
    End

    It "calls start_disk() with raw device"
        detect_raw_disk() {
            echo raw-device
        }

        When call ensure_formated_and_mounted
        The output should eq "raw-device"
    End

    It "call partition to format when raw disk also present"
        detect_partition() {
            echo some-uuid
        }

        detect_raw_disk() {
            echo ignored-device
        }

        When call ensure_formated_and_mounted
        The output should eq "some-uuid"
    End

    It "ignore many partitions when has raw disk"
        detect_partition() {
            echo ignored-part
            echo ignored-part
        }

        detect_raw_disk() {
            echo raw-device
        }

        When call ensure_formated_and_mounted
        The output should eq "raw-device"
    End

    It "ignore many disks when has partition"
        detect_partition() {
            echo some-uuid
        }

        detect_raw_disk() {
            echo ignored-device
            echo ignored-device
        }

        When call ensure_formated_and_mounted
        The output should eq "some-uuid"
    End

    It "calls start_disk() from environment"
        start_with_templated_dev() {
            # shellcheck disable=SC2034
            TEMPLATED_DEV=templated-test

            ensure_formated_and_mounted
        }

        When call start_with_templated_dev
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

Describe "start_disk()"
    prepare_disk_when_raw() {
        :
    }

    check_filesystem() {
        :
    }

    mount() {
        :
    }

    It "fails on prepare_disk_when_raw()"
        prepare_disk_when_raw() {
            return 123
        }

        # shellcheck disable=SC2154
        When call start_disk "$test_disk"
        The status should eq 123
    End

    It "fails on check_filesystem()"
        check_filesystem() {
            return 123
        }

        # shellcheck disable=SC2154
        When call start_disk "$test_disk"
        The status should eq 123
    End

    It "mounts with rw_dir"
        mount() {
            echo "$2"
        }

        # shellcheck disable=SC2154
        When call start_disk "$test_disk"
        The status should eq 0

        # shellcheck disable=SC2154
        The output should start with "$rw_dir"
    End

    It "fails with mount error status code"
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

Describe "prepare_disk_when_raw()"
    with_disk_prepared() {
        prepare_disk_when_raw "$test_disk"
    }

    is_raw_disk() {
        :
    }

    check_filesystem() {
        :
    }

    Context 'when not raw'
        Before "with_disk_prepared"

        is_raw_disk() {
            return 1
        }

        It "does not format the disk"
            Mock mkfs.ext4
                exit 255
            End

            When call with_disk_prepared
            The status should eq 0
            The entire output should eq ''
        End
    End

    It 'fails with fs error code'
        # fake a mkfs error
        Mock mkfs.ext4
            exit 1
        End

        When call with_disk_prepared

        # shellcheck disable=SC2154
        The status should eq "$file_system_err"
        The stderr should include failed
    End
End

Describe "replace_local_dns" current:test
    Context "not-debian"
        create_dummy_hosts() {
            # shellcheck disable=SC2154
            cat <<EOF > "$hosts_file"
127.0.0.1   localhost localhost.localdomain
::1         localhost localhost.localdomain

9.9.9.9     example.test
EOF
        }

        has_hostname() {
            hostname="${1:?}"

            cmp_file="$(mktemp)"
            cat <<EOF > "$cmp_file"
127.0.0.1   localhost localhost.localdomain ${hostname}
::1         localhost localhost.localdomain ${hostname}

9.9.9.9     example.test
EOF

            same_contents "$hosts_file" "$cmp_file"
        }

        Before "create_dummy_hosts"
        
        # mocking
        is_running_debian() {
            return 1
        }

        It "uses 127.0.0.1 by default"
            When call replace_local_dns "foo"
            The status should be success

            Assert has_hostname "foo"
        End
    End

    Context "on-debian"
        create_dummy_hosts() {
            # shellcheck disable=SC2154
            cat <<EOF > "$hosts_file"
127.0.0.1   localhost localhost.localdomain
127.0.1.1   old-foo-hostname
::1         localhost localhost.localdomain

9.9.9.9     example.test
EOF
        }

        has_hostname() {
            hostname="${1:?}"

            cmp_file="$(mktemp)"
            cat <<EOF > "$cmp_file"
127.0.0.1   localhost localhost.localdomain
127.0.1.1   old-foo-hostname ${hostname}
::1         localhost localhost.localdomain ${hostname}

9.9.9.9     example.test
EOF

            same_contents "$hosts_file" "$cmp_file"
        }

        Before "create_dummy_hosts"
        
        # mocking
        is_running_debian() {
            return 0
        }

        It "uses 127.0.1.1 by default"
            When call replace_local_dns "foo"
            The status should be success

            Assert has_hostname "foo"
        End
    End
End