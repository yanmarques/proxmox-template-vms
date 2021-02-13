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
        When call setup_vm_user_data
        The entire output should not include failed
        Assert has_default_rw_files
    End

    It "keeps already present config files"
        make_two_setups() {
            setup_vm_user_data

            # shellcheck disable=SC2154
            echo testing > "$rw_dir"/config/rc.local
            echo testing > "$rw_dir"/config/bind-dirs.manifest
            
            setup_vm_user_data
        }

        When call make_two_setups
        The entire output should not include failed
        Assert same_contents "$rw_dir"/config/rc.local "$rw_dir"/config/bind-dirs.manifest
    End
End