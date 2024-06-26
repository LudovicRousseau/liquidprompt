
# Error on unset variables
set -u

if [ -n "${ZSH_VERSION-}" ]; then
  SHUNIT_PARENT="$0"
  setopt shwordsplit ksh_arrays
fi

. ../liquidprompt --no-activate

LP_ENABLE_DISK=1
LP_DISK_PRECISION=2

typeset -a names outputs values values_human

names+=("Simple Linux")
outputs+=(
'Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/nvme0n1p2   479608528 425188220  30011332      94% /'
)
values+=(30011332)
values_human+=("28.62 GiB")

names+=("Cygwin with space on FS")
outputs+=(
'Filesystem                1024-blocks      Used  Available Capacity Mounted on
C:/Program Files/cygwin64  1999659004 450860152 1548798852      23% /'
)
values+=(1548798852)
values_human+=("1.44 TiB")

names+=("Cygwin with space on mount point")
outputs+=(
'Filesystem                1024-blocks      Used  Available Capacity Mounted on
C:/Program Files/cygwin64  1999659004 450860152 1548798852      23% C:/Program Files/cygwin64/drive_d'
)
values+=(1548798852)
values_human+=("1.44 TiB")

names+=("FreeBSD small FS, but over 1MB")
outputs+=(
'Filesystem      1024-blocks Used Avail Capacity  Mounted on
/dev/gpt/efiesp       32764  646 32117     2%    /boot/efi'
)
values+=(32117)
values_human+=("31.36 MiB")

names+=("FreeBSD special FS")
outputs+=(
'Filesystem 1024-blocks Used Avail Capacity  Mounted on
devfs                1    0     1     0%    /dev'
)
values+=("")
values_human+=("")

names+=("Linux special FS")
outputs+=(
'Filesystem     1024-blocks  Used Available Capacity Mounted on
sysfs                    0     0         0        - /sys'
)
values+=("")
values_human+=("")

function test_disk {
    for (( i=0; i < ${#outputs[@]}; i++ )); do
        df() {
            printf '%s\n' "${outputs[i]}"
        }

        LP_DISK_THRESHOLD_PERC=99
        LP_DISK_THRESHOLD=10000000000
        if [ -n "${values[i]}" ]; then
            _lp_disk
            assertEquals "Parsing of \"${names[i]}\" without error" "0" "$?"
            assertEquals "Correct parsing of \"${names[i]}\" in KiB" "${values[i]}" "$lp_disk"
            assertEquals "Correct parsing of \"${names[i]}\" for human" "${values_human[i]}" "$lp_disk_human $lp_disk_human_units"
        else
            _lp_disk
            assertFalse "Parsing of \"${names[i]}\" skipped" "$?"
        fi

        # Note: percent threshold should be below available space in the least
        #       available space case ("Simple Linux"), but absolute threshold
        #       should be slightly larger than "FreeBSD small FS" test case,
        #       so we can fully test the "total >= LP_DISK_THRESHOLD" condition.
        LP_DISK_THRESHOLD_PERC=5
        LP_DISK_THRESHOLD=100000
        _lp_disk
        assertFalse "Above threshold for \"${names[i]}\"" "$?"
    done
}

function test_bytes_to_human {
    LP_DISK_PRECISION=0

    local -a units
    units=("B" "KiB" "MiB" "GiB" "TiB" "PiB" "EiB" "YiB" "ZiB")

    for (( i=1; i < 7; i++ )); do
        __lp_bytes_to_human $((1024**i)) "$LP_DISK_PRECISION"
        assertEquals "Human readable 1024**$i" "1024 ${units[i-1]}" "$lp_bytes $lp_bytes_units"
    done

    for (( i=1; i < 7; i++ )); do
        __lp_bytes_to_human $((1025**i)) "$LP_DISK_PRECISION"
        assertEquals "Human readable 1025**$i" "1 ${units[i]}" "$lp_bytes $lp_bytes_units"
    done

    for (( i=1; i < 7; i++ )); do
        __lp_bytes_to_human $((2*1024**i)) "$LP_DISK_PRECISION"
        assertEquals "Human readable 2*1024**$i" "2 ${units[i]}" "$lp_bytes $lp_bytes_units"
    done

    LP_DISK_PRECISION=1

    for (( i=1; i < 7; i++ )); do
        __lp_bytes_to_human $((1024**i)) "$LP_DISK_PRECISION"
        assertEquals "Human readable 1024**$i" "1024.0 ${units[i-1]}" "$lp_bytes $lp_bytes_units"
    done

    LP_DISK_PRECISION=2

    for (( i=1; i < 7; i++ )); do
        __lp_bytes_to_human $((1024**i)) "$LP_DISK_PRECISION"
        assertEquals "Human readable 1024**$i" "1024.00 ${units[i-1]}" "$lp_bytes $lp_bytes_units"
    done

}

. ./shunit2

