# shellcheck shell=bash

Include ./tests/unix/linux/functions

BeforeEach "setup"
AfterEach "teardown"

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