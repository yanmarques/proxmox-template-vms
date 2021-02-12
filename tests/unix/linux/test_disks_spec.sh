# shellcheck shell=bash

Include ./tests/unix/linux/include.sh

BeforeEach "setup"
AfterEach "teardown"

It "recognizes dummy created disk as raw"
    When call checks_dummy_disk_is_raw
    The status should be success
End

It 'format raw testing disk'
    When call with_raw_disk_formated
    The status should be success
    The stderr should include "Found a dos partition table"
    The stdout should not include "failed"
    The variable test_disk should satisfy is_disk
End

It "format already formated disk keep it's content"
    When call format_an_already_formated_disk_does_nothing
    The status should be success
    The stdout should not include "failed"
    The stderr should include "Found a dos partition table"
End
