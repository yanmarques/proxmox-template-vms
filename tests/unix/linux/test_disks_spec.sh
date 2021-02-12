# shellcheck shell=bash

Include ./tests/unix/linux/include.sh

BeforeEach "setup"
AfterEach "teardown"

It 'format raw testing disk'
    When call with_raw_disk_formated
    The output should not include failed
    The line 2 of stderr should start with "Found a dos partition table"
    The variable test_disk should satisfy is_disk
End

