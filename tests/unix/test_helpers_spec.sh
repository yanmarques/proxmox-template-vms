# shellcheck shell=bash

Describe "templated_exec()"

    It "fails when missing user input"
        When call templated_exec
        The status should eq 1
        The output should start with "Usage"
    End

    It "exits with start_exec() status code"
        start_exec() {
            return 123
        }
    
        When call templated_exec "some"
        The status should eq 123
    End
End

Describe "start_exec()"
     It "fails with exit code of hook function"
        pre_start() {
            return 54
        }

        When call templated_exec "some"
        The status should eq 54
    End

    It "exits when detect a template vm"
        # fake a template vm
        disks_counter() {
            echo 1
        }

        # this should never be called
        pre_start() {
            return 11
        }

        When call templated_exec "some"
        The status should be success
    End
End

Describe "exec_log()"

    It "shows info with success status code"
        tester() {
            :
        }

        When call exec_log "templated-test" tester
        The status should be success
        The output should include "templated-test [tester]: succeded"
    End

    It "shows error and exit with function custom status code"
        tester() {
            return 123
        }

        When call exec_log "templated-test" tester
        The status should eq 123
        The stderr should include "templated-test [tester]: failed"
    End

End