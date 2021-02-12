# shellcheck shell=bash

Include ./tests/unix/linux/include.sh

BeforeEach "setup"
AfterEach "teardown"

It 'trigger disk configuration'
    When call with_disk_started
    The variable test_disk should satisfy mounted
End

