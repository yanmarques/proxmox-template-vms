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