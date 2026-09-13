#!/usr/bin/env python3
"""Stream Linux system, cgroup, and process resource statistics over SSH.

Only a POSIX shell and common command-line tools are required on the target.
Python and AsyncSSH run exclusively on the local machine.
"""

import argparse
import asyncio
import csv
import json
import shlex
import sys
import time
from datetime import datetime, timezone
from textwrap import dedent
from typing import Any, Dict, List, Optional, Tuple

import asyncssh


Sample = Dict[str, Any]
ProcessStats = Dict[str, Any]

ERROR_RECORD = "E"
SUMMARY_RECORD = "S"
MEMORY_RECORD = "M"
PROCESS_COUNT_RECORD = "C"
PROCESS_RECORD = "P"


# This collector deliberately uses only POSIX shell and common BusyBox tools.
# Each output line is a small tab-separated record parsed by the local client.
CGROUP_DISCOVERY_SH = dedent(r'''
# Input arguments
selector_type=$1
selector=$2
include_breakdown=$3
include_process_stats=$4

# Detect cgroup version and memory hierarchy root.
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
    root=/sys/fs/cgroup
    version=2
    pid_file=cgroup.procs
else
    root=/sys/fs/cgroup/memory
    version=1
    pid_file=tasks
fi

# Return the memory cgroup path associated with a host PID.
pid_cgroup() {
    target_pid=$1
    if [ "$version" -eq 2 ]; then
        awk -F: '$1 == "0" {print $3; exit}' "/proc/$target_pid/cgroup" 2>/dev/null
    else
        awk -F: '$2 ~ /(^|,)memory(,|$)/ {print $3; exit}' "/proc/$target_pid/cgroup" 2>/dev/null
    fi
}

# DobbyTool info may provide the complete container PID list. Keep it separate
# so process collection can use that authoritative list instead of rediscovery.
selected_pids=

# Resolve the requested cgroup from a path, PID, process, or Dobby ID.
case "$selector_type" in
    cgroup)
        requested=$selector
        ;;
    pid)
        case "$selector" in *[!0-9]*|'') printf 'E\tinvalid PID: %s\n' "$selector"; exit 2 ;; esac
        requested=$(pid_cgroup "$selector")
        ;;
    process)
        app_pid=$(pgrep -x "$selector" 2>/dev/null | tail -n 1)
        if [ -z "$app_pid" ]; then
            for candidate in $(pgrep -f "$selector" 2>/dev/null); do
                [ "$candidate" = "$$" ] && continue
                [ "$candidate" = "$PPID" ] && continue
                [ -d "/proc/$candidate" ] || continue
                app_pid=$candidate
            done
        fi
        [ -n "$app_pid" ] || { printf 'E\tprocess not found: %s\n' "$selector"; exit 2; }
        requested=$(pid_cgroup "$app_pid")
        ;;
    dobby)
        app_pid=
        dobby_info=$(DobbyTool info "$selector" 2>/dev/null)
        dobby_pids=$(printf '%s\n' "$dobby_info" | sed -n \
            's/.*"pids"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' | \
            tr ',' ' ')

        for candidate in $dobby_pids; do
            case "$candidate" in *[!0-9]*|'') continue ;; esac
            [ -d "/proc/$candidate" ] || continue
            selected_pids="$selected_pids $candidate"
            [ -n "$app_pid" ] || app_pid=$candidate
        done

        # Support older DobbyTool builds which do not return a pids array.
        if [ -z "$app_pid" ]; then
            for cgroup_file in /proc/[0-9]*/cgroup; do
                if grep -F "$selector" "$cgroup_file" >/dev/null 2>&1; then
                    app_pid=${cgroup_file#/proc/}
                    app_pid=${app_pid%/cgroup}
                    break
                fi
            done
        fi
        [ -n "$app_pid" ] || { printf 'E\tDobby container not found in cgroups: %s\n' "$selector"; exit 2; }
        requested=$(pid_cgroup "$app_pid")
        ;;
    *)
        printf 'E\tunknown selector type: %s\n' "$selector_type"
        exit 2
        ;;
esac

[ -n "$requested" ] || { printf 'E\tcgroup not found for selector: %s\n' "$selector"; exit 2; }

case "$requested" in
    /sys/fs/cgroup/*) cgroup=$requested ;;
    /*) cgroup=$root$requested ;;
    *) cgroup=$root/$requested ;;
esac

if [ ! -d "$cgroup" ]; then
    printf 'E\tcgroup not found: %s\n' "$cgroup"
    exit 2
fi

read_value() {
    if [ -r "$1" ]; then
        cat "$1" 2>/dev/null
    fi
}
''')


CGROUP_STATS_SH = dedent(r'''
# Collect cgroup-level memory and CPU counters.
if [ "$version" -eq 2 ]; then
    current=$(read_value "$cgroup/memory.current")
    peak=$(read_value "$cgroup/memory.peak")
    limit=$(read_value "$cgroup/memory.max")
    oom=$(awk '$1 == "oom" {print $2}' "$cgroup/memory.events" 2>/dev/null)
    oom_kill=$(awk '$1 == "oom_kill" {print $2}' "$cgroup/memory.events" 2>/dev/null)
    cpu_usage=$(awk '$1 == "usage_usec" {printf "%.0f", $2 * 1000}' \
        "$cgroup/cpu.stat" 2>/dev/null)
else
    current=$(read_value "$cgroup/memory.usage_in_bytes")
    peak=$(read_value "$cgroup/memory.max_usage_in_bytes")
    limit=$(read_value "$cgroup/memory.limit_in_bytes")
    oom=
    oom_kill=
    relative=${cgroup#"$root"}
    cpu_root=$(awk '$3 == "cgroup" && $4 ~ /(^|,)cpuacct(,|$)/ {print $2; exit}' \
        /proc/mounts 2>/dev/null)
    cpu_usage=$(read_value "$cpu_root$relative/cpuacct.usage")
fi

clock_ticks=$(getconf CLK_TCK 2>/dev/null)
[ -n "$clock_ticks" ] || clock_ticks=100
cpu_count=$(getconf _NPROCESSORS_ONLN 2>/dev/null)
[ -n "$cpu_count" ] || cpu_count=$(awk '/^processor[[:space:]]*:/ {n++} END {print n+0}' /proc/cpuinfo)
[ "$cpu_count" -gt 0 ] 2>/dev/null || cpu_count=1
''')


SYSTEM_STATS_SH = dedent(r'''
# Collect whole-system memory and CPU counters.
system_memory=$(awk '
    $1 == "MemTotal:" {total=$2}
    $1 == "MemAvailable:" {available=$2}
    $1 == "MemFree:" {free=$2}
    $1 == "Buffers:" {buffers=$2}
    $1 == "Cached:" {cached=$2}
    $1 == "SReclaimable:" {reclaimable=$2}
    $1 == "Shmem:" {shmem=$2}
    END {
        if (!available) available=free+buffers+cached+reclaimable-shmem
        print total, available
    }
' /proc/meminfo 2>/dev/null)
set -- $system_memory
system_total_kb=${1:--}
system_available_kb=${2:--}

system_cpu=$(awk '/^cpu[[:space:]]/ {
    idle=$5+$6
    for (i=2; i<=NF; i++) total+=$i
    print total, idle
    exit
}' /proc/stat 2>/dev/null)
set -- $system_cpu
system_cpu_total=${1:--}
system_cpu_idle=${2:--}

printf 'S\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$version" "$current" "$peak" "$limit" "$oom" "$oom_kill" \
    "$cgroup" "$cpu_usage" "$clock_ticks" "$cpu_count" \
    "$system_total_kb" "$system_available_kb" "$system_cpu_total" "$system_cpu_idle"
''')


MEMORY_BREAKDOWN_SH = dedent(r'''
# Optionally collect detailed cgroup memory counters.
if [ "$include_breakdown" = "1" ]; then
    memory_stat="$cgroup/memory.stat"
    if [ "$version" -eq 2 ]; then
        breakdown=$(awk '
            $1 == "anon" {anon=$2}
            $1 == "file" {file=$2}
            $1 == "kernel" {kernel=$2; have_kernel=1}
            $1 == "kernel_stack" {kernel_stack=$2}
            $1 == "pagetables" {pagetables=$2}
            $1 == "sock" {sock=$2}
            $1 == "shmem" {shmem=$2}
            $1 == "slab" {slab=$2}
            $1 == "pgfault" {pgfault=$2}
            $1 == "pgmajfault" {pgmajfault=$2}
            END {
                if (!have_kernel) kernel=kernel_stack+pagetables+sock
                print anon+0, file+0, kernel+0, shmem+0, slab+0, pgfault+0, pgmajfault+0
            }
        ' "$memory_stat" 2>/dev/null)
    else
        breakdown=$(awk '
            $1 == "rss" {anon=$2}
            $1 == "cache" {file=$2}
            $1 == "kernel_stack" {kernel_stack=$2}
            $1 == "pagetables" {pagetables=$2}
            $1 == "shmem" {shmem=$2}
            $1 == "slab" {slab=$2}
            $1 == "pgfault" {pgfault=$2}
            $1 == "pgmajfault" {pgmajfault=$2}
            END {
                print anon+0, file+0, kernel_stack+pagetables, shmem+0, slab+0, pgfault+0, pgmajfault+0
            }
        ' "$memory_stat" 2>/dev/null)
    fi
    set -- $breakdown
    printf 'M\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${1:--}" "${2:--}" "${3:--}" "${4:--}" "${5:--}" "${6:--}" "${7:--}"
fi
''')


PROCESS_STATS_SH = dedent(r'''
# Dobby supplies its container PIDs directly. Other selectors use cgroup
# membership, including all descendant cgroups.
if [ -n "$selected_pids" ]; then
    pids=$(printf '%s\n' $selected_pids | sort -nu)
else
    pids=$(find "$cgroup" -type f -name "$pid_file" -exec cat {} \; 2>/dev/null | sort -nu)
fi
process_count=$(printf '%s\n' "$pids" | awk 'NF {count++} END {print count+0}')
printf 'C\t%s\n' "$process_count"

if [ "$include_process_stats" = "1" ]; then
    printf '%s\n' "$pids" | while IFS= read -r pid; do
    case "$pid" in *[!0-9]*|'') continue ;; esac
    proc=/proc/$pid
    [ -d "$proc" ] || continue

    if [ -r "$proc/smaps_rollup" ]; then
        values=$(awk '
            $1 == "Rss:" {rss=$2}
            $1 == "Pss:" {pss=$2}
            $1 == "Private_Clean:" {pc=$2}
            $1 == "Private_Dirty:" {pd=$2}
            $1 == "Swap:" {swap=$2}
            END {printf "%s %s %s %s", rss, pss, pc+pd, swap}
        ' "$proc/smaps_rollup" 2>/dev/null)
    else
        values=$(awk '
            $1 == "VmRSS:" {rss=$2}
            $1 == "VmSwap:" {swap=$2}
            END {printf "%s - - %s", rss, swap}
        ' "$proc/status" 2>/dev/null)
    fi

    set -- $values
    rss=${1:--}
    pss=${2:--}
    uss=${3:--}
    swap=${4:--}
    name=$(tr '\t\r\n' '   ' < "$proc/comm" 2>/dev/null)
    command=$(tr '\000\t\r\n' '    ' < "$proc/cmdline" 2>/dev/null)
    stat_values=$(sed 's/^.*) //' "$proc/stat" 2>/dev/null | \
        awk '{print $2, $12+$13, $20}')
    set -- $stat_values
    ppid=${1:--}
    cpu_ticks=${2:--}
    start_ticks=${3:--}
    threads=$(awk '$1 == "Threads:" {print $2}' "$proc/status" 2>/dev/null)
    [ -n "$threads" ] || threads=-
    executable=$(readlink "$proc/exe" 2>/dev/null | tr '\t\r\n' '   ')
    printf 'P\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$pid" "$ppid" "$rss" "$pss" "$uss" "$swap" "$cpu_ticks" \
        "$start_ticks" "$threads" "$name" "$executable" "$command"
done
fi
''')


REMOTE_COLLECTOR_SH = "\n".join((
    CGROUP_DISCOVERY_SH,
    CGROUP_STATS_SH,
    SYSTEM_STATS_SH,
    MEMORY_BREAKDOWN_SH,
    PROCESS_STATS_SH,
))


def human_bytes(value: Optional[int]) -> str:
    """Format a byte count using binary units."""
    if value is None:
        return "-"
    amount = float(value)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if abs(amount) < 1024 or unit == "TiB":
            return f"{amount:.1f}{unit}"
        amount /= 1024
    return "-"


def parse_number(value: str, multiplier: int = 1) -> Optional[int]:
    """Parse an optional integer emitted by the remote collector."""
    if not value or value in {"-", "max"}:
        return None
    try:
        return int(value) * multiplier
    except ValueError:
        return None


def parse_summary_record(fields: List[str]) -> Sample:
    """Parse the main cgroup and system record."""
    if len(fields) != 15:
        raise RuntimeError("invalid summary record from target")

    cgroup_version = int(fields[1])
    memory_limit = parse_number(fields[4])
    return {
        "cgroup_version": cgroup_version,
        "cgroup": fields[7],
        "cpu": {
            "usage_ns": parse_number(fields[8]),
            "clock_ticks": parse_number(fields[9]) or 100,
            "cpu_count": parse_number(fields[10]) or 1,
            "usage_percent": None,
        },
        "system": {
            "memory_total_bytes": parse_number(fields[11], 1024),
            "memory_available_bytes": parse_number(fields[12], 1024),
            "memory_used_bytes": None,
            "memory_used_percent": None,
            "cpu_total_ticks": parse_number(fields[13]),
            "cpu_idle_ticks": parse_number(fields[14]),
            "cpu_percent": None,
        },
        "memory": {
            "current_bytes": parse_number(fields[2]),
            "peak_bytes": parse_number(fields[3]),
            "limit_bytes": memory_limit,
            "limit_unlimited": fields[4] == "max" or (
                cgroup_version == 1
                and memory_limit is not None
                and memory_limit >= (1 << 60)
            ),
            "oom_events": parse_number(fields[5]),
            "oom_kill_events": parse_number(fields[6]),
            "breakdown": None,
        },
    }


def parse_memory_record(fields: List[str]) -> Dict[str, Optional[int]]:
    """Parse the optional cgroup memory breakdown record."""
    if len(fields) != 8:
        raise RuntimeError("invalid memory breakdown record from target")
    names = (
        "anon_bytes",
        "file_bytes",
        "kernel_bytes",
        "shmem_bytes",
        "slab_bytes",
        "page_faults",
        "major_page_faults",
    )
    return {name: parse_number(value) for name, value in zip(names, fields[1:])}


def detect_process_type(
    name: str,
    executable: str,
    command: str,
) -> Tuple[str, str]:
    """Use explicit process metadata without guessing an internal role."""
    arguments = command.split()
    for index, argument in enumerate(arguments):
        if argument.startswith("--type="):
            return argument.split("=", 1)[1], "cmdline"
        if argument == "--type" and index + 1 < len(arguments):
            return arguments[index + 1], "cmdline"

    if executable:
        return executable.rsplit("/", 1)[-1], "executable"
    if name:
        return name, "comm"
    return "unknown", "unavailable"


def parse_process_record(fields: List[str]) -> ProcessStats:
    """Parse one process and attach its factual type and source."""
    if len(fields) < 13:
        raise RuntimeError("invalid process record from target")
    name = fields[10] or "?"
    executable = fields[11]
    command = "\t".join(fields[12:]).strip()
    process_type, type_source = detect_process_type(name, executable, command)
    return {
        "pid": int(fields[1]),
        "ppid": parse_number(fields[2]),
        "rss_bytes": parse_number(fields[3], 1024),
        "pss_bytes": parse_number(fields[4], 1024),
        "uss_bytes": parse_number(fields[5], 1024),
        "swap_bytes": parse_number(fields[6], 1024),
        "cpu_ticks": parse_number(fields[7]),
        "start_ticks": parse_number(fields[8]),
        "threads": parse_number(fields[9]),
        "cpu_percent": None,
        "name": name,
        "executable": executable,
        "command": command,
        "type": process_type,
        "type_source": type_source,
    }


def add_system_memory_usage(sample: Sample) -> None:
    """Derive used system memory from total and available memory."""
    system = sample["system"]
    total = system["memory_total_bytes"]
    available = system["memory_available_bytes"]
    if total is None or available is None:
        return

    used = max(total - available, 0)
    system["memory_used_bytes"] = used
    system["memory_used_percent"] = used / total * 100 if total else None


def parse_collector_output(output: str) -> Sample:
    """Convert tab-separated remote records into one sample dictionary."""
    sample = None  # type: Optional[Sample]
    memory_breakdown = None
    process_count = None
    processes = []  # type: List[ProcessStats]

    for line in output.splitlines():
        fields = line.split("\t")
        record_type = fields[0]

        if record_type == ERROR_RECORD:
            message = fields[1] if len(fields) > 1 else "remote collector failed"
            raise RuntimeError(message)
        if record_type == SUMMARY_RECORD:
            sample = parse_summary_record(fields)
        elif record_type == MEMORY_RECORD:
            memory_breakdown = parse_memory_record(fields)
        elif record_type == PROCESS_RECORD:
            processes.append(parse_process_record(fields))
        elif record_type == PROCESS_COUNT_RECORD and len(fields) == 2:
            process_count = parse_number(fields[1])

    if sample is None:
        raise RuntimeError("remote collector returned no cgroup data")

    processes.sort(key=lambda process: process.get("rss_bytes") or 0, reverse=True)
    sample["memory"]["breakdown"] = memory_breakdown
    sample["timestamp"] = datetime.now(timezone.utc).isoformat()
    sample["process_count"] = process_count if process_count is not None else len(processes)
    sample["processes"] = processes
    add_system_memory_usage(sample)
    return sample


def update_system_cpu(sample: Sample, previous: Sample) -> None:
    """Calculate normalized whole-system CPU usage (0-100%)."""
    current = sample["system"]
    old = previous["system"]
    values = (
        current.get("cpu_total_ticks"),
        old.get("cpu_total_ticks"),
        current.get("cpu_idle_ticks"),
        old.get("cpu_idle_ticks"),
    )
    if any(value is None for value in values):
        return

    total_delta = values[0] - values[1]
    idle_delta = values[2] - values[3]
    if total_delta > 0:
        busy_percent = (total_delta - idle_delta) / total_delta * 100
        current["cpu_percent"] = max(min(busy_percent, 100), 0)


def update_cgroup_cpu(sample: Sample, previous: Sample, elapsed: float) -> None:
    """Calculate cgroup CPU usage where 100% represents one CPU core."""
    current_usage = sample["cpu"].get("usage_ns")
    old_usage = previous["cpu"].get("usage_ns")
    if current_usage is None or old_usage is None:
        return

    usage_delta = current_usage - old_usage
    if usage_delta >= 0:
        sample["cpu"]["usage_percent"] = (
            usage_delta / (elapsed * 1_000_000_000) * 100
        )


def update_process_cpu(sample: Sample, previous: Sample, elapsed: float) -> None:
    """Calculate CPU usage for processes which existed in both samples."""
    old_processes = {
        (process["pid"], process.get("start_ticks")): process
        for process in previous["processes"]
    }
    clock_ticks = sample["cpu"].get("clock_ticks") or 100

    for process in sample["processes"]:
        identity = (process["pid"], process.get("start_ticks"))
        old = old_processes.get(identity)
        if old is None:
            continue

        current_ticks = process.get("cpu_ticks")
        old_ticks = old.get("cpu_ticks")
        if current_ticks is None or old_ticks is None:
            continue

        tick_delta = current_ticks - old_ticks
        if tick_delta >= 0:
            process["cpu_percent"] = tick_delta / clock_ticks / elapsed * 100


def add_cpu_percentages(
    sample: Sample,
    previous: Optional[Sample],
    elapsed: Optional[float],
) -> None:
    """Enrich a sample using differences from the previous sample."""
    if previous is None or elapsed is None or elapsed <= 0:
        return

    update_system_cpu(sample, previous)
    update_cgroup_cpu(sample, previous, elapsed)
    update_process_cpu(sample, previous, elapsed)


def format_percent(value: Optional[float]) -> str:
    return "-" if value is None else "{:.1f}%".format(value)


def process_memory_totals(processes: List[ProcessStats]) -> Dict[str, Optional[int]]:
    """Sum the available memory counters across all reported processes."""
    totals = {}  # type: Dict[str, Optional[int]]
    for field in ("rss_bytes", "pss_bytes", "uss_bytes"):
        values = [process[field] for process in processes if process.get(field) is not None]
        totals[field] = sum(values) if values else None
    return totals


def display_system(sample: Sample) -> None:
    system = sample["system"]
    print(
        "\nSYSTEM  CPU={}  RAM={}/{} ({})".format(
            format_percent(system.get("cpu_percent")),
            human_bytes(system.get("memory_used_bytes")),
            human_bytes(system.get("memory_total_bytes")),
            format_percent(system.get("memory_used_percent")),
        )
    )


def display_cgroup(sample: Sample) -> None:
    memory = sample["memory"]
    limit = (
        "unlimited"
        if memory.get("limit_unlimited")
        else human_bytes(memory.get("limit_bytes"))
    )
    print(
        "{}  cgroup-v{}  memory={}  peak={}  limit={}  CPU={}  processes={}".format(
            sample["timestamp"],
            sample["cgroup_version"],
            human_bytes(memory.get("current_bytes")),
            human_bytes(memory.get("peak_bytes")),
            limit,
            format_percent(sample["cpu"].get("usage_percent")),
            sample["process_count"],
        )
    )


def display_memory_breakdown(sample: Sample) -> None:
    breakdown = sample["memory"].get("breakdown")
    if breakdown is None:
        return
    print(
        "memory breakdown: anon={}  file={}  kernel={}  shmem={}  slab={}  "
        "faults={}  major-faults={}".format(
            human_bytes(breakdown["anon_bytes"]),
            human_bytes(breakdown["file_bytes"]),
            human_bytes(breakdown["kernel_bytes"]),
            human_bytes(breakdown["shmem_bytes"]),
            human_bytes(breakdown["slab_bytes"]),
            breakdown["page_faults"] or 0,
            breakdown["major_page_faults"] or 0,
        )
    )


def process_tree_order(
    processes: List[ProcessStats],
) -> List[Tuple[int, ProcessStats]]:
    """Return processes in parent-first order with their tree depth."""
    by_pid = {process["pid"]: process for process in processes}
    children = {}  # type: Dict[int, List[ProcessStats]]
    roots = []  # type: List[ProcessStats]

    for process in processes:
        parent = process.get("ppid")
        if parent in by_pid:
            children.setdefault(parent, []).append(process)
        else:
            roots.append(process)

    ordered = []  # type: List[Tuple[int, ProcessStats]]

    def visit(process: ProcessStats, depth: int) -> None:
        ordered.append((depth, process))
        for child in sorted(children.get(process["pid"], []), key=lambda item: item["pid"]):
            visit(child, depth + 1)

    for root in sorted(roots, key=lambda item: item["pid"]):
        visit(root, 0)
    return ordered


def display_processes(sample: Sample) -> None:
    if not sample.get("process_stats_enabled", True):
        return

    processes = sample["processes"]
    totals = process_memory_totals(processes)
    print(
        "process totals: RSS={}  PSS={}  USS={}".format(
            human_bytes(totals["rss_bytes"]),
            human_bytes(totals["pss_bytes"]),
            human_bytes(totals["uss_bytes"]),
        )
    )
    print(
        "{:>7} {:>7} {:>5} {:>7} {:>10} {:>10} {:>10} {:>10}  {:<20} {:<10} COMMAND".format(
            "PID", "PPID", "THR", "CPU", "RSS", "PSS", "USS", "SWAP",
            "TYPE", "SOURCE"
        )
    )
    if sample.get("process_tree_enabled"):
        rows = process_tree_order(processes)
    else:
        rows = [(0, process) for process in processes]

    for depth, process in rows:
        command = process["command"] or process["name"]
        process_type = "  " * depth + process["type"]
        print(
            "{:>7} {:>7} {:>5} {:>7} {:>10} {:>10} {:>10} {:>10}  {:<20} {:<10} {}".format(
                process["pid"],
                process.get("ppid") or "-",
                process.get("threads") or "-",
                format_percent(process.get("cpu_percent")),
                human_bytes(process.get("rss_bytes")),
                human_bytes(process.get("pss_bytes")),
                human_bytes(process.get("uss_bytes")),
                human_bytes(process.get("swap_bytes")),
                process_type,
                process["type_source"],
                command,
            )
        )


def display(sample: Sample, json_output: bool) -> None:
    """Write one sample in JSON or human-readable form."""
    if json_output:
        print(json.dumps(sample, separators=(",", ":")), flush=True)
        return

    display_system(sample)
    display_cgroup(sample)
    display_memory_breakdown(sample)
    display_processes(sample)


CSV_FIELDS = (
    "timestamp", "system_cpu_percent", "system_memory_used_bytes",
    "system_memory_available_bytes", "system_memory_total_bytes",
    "system_memory_used_percent", "cgroup", "cgroup_version", "cgroup_cpu_percent",
    "cgroup_cpu_usage_ns", "cpu_count", "cgroup_current_bytes",
    "cgroup_peak_bytes", "cgroup_limit_bytes", "cgroup_limit_unlimited",
    "cgroup_anon_bytes", "cgroup_file_bytes", "cgroup_kernel_bytes",
    "cgroup_shmem_bytes", "cgroup_slab_bytes", "cgroup_page_faults",
    "cgroup_major_page_faults",
    "process_count", "process_rss_total_bytes", "process_pss_total_bytes",
    "process_uss_total_bytes", "pid", "ppid", "name", "process_type",
    "type_source", "threads", "executable", "cpu_percent", "cpu_ticks",
    "rss_bytes", "pss_bytes", "uss_bytes", "swap_bytes", "command",
)


def build_csv_base_row(sample: Sample) -> Dict[str, Any]:
    """Build fields which are repeated for every process row."""
    memory = sample["memory"]
    system = sample["system"]
    breakdown = memory.get("breakdown") or {}
    totals = process_memory_totals(sample["processes"])
    return {
        "timestamp": sample["timestamp"],
        "system_cpu_percent": system.get("cpu_percent"),
        "system_memory_used_bytes": system.get("memory_used_bytes"),
        "system_memory_available_bytes": system.get("memory_available_bytes"),
        "system_memory_total_bytes": system.get("memory_total_bytes"),
        "system_memory_used_percent": system.get("memory_used_percent"),
        "cgroup": sample["cgroup"],
        "cgroup_version": sample["cgroup_version"],
        "cgroup_cpu_percent": sample["cpu"].get("usage_percent"),
        "cgroup_cpu_usage_ns": sample["cpu"].get("usage_ns"),
        "cpu_count": sample["cpu"].get("cpu_count"),
        "cgroup_current_bytes": memory["current_bytes"],
        "cgroup_peak_bytes": memory["peak_bytes"],
        "cgroup_limit_bytes": memory["limit_bytes"],
        "cgroup_limit_unlimited": memory.get("limit_unlimited", False),
        "cgroup_anon_bytes": breakdown.get("anon_bytes"),
        "cgroup_file_bytes": breakdown.get("file_bytes"),
        "cgroup_kernel_bytes": breakdown.get("kernel_bytes"),
        "cgroup_shmem_bytes": breakdown.get("shmem_bytes"),
        "cgroup_slab_bytes": breakdown.get("slab_bytes"),
        "cgroup_page_faults": breakdown.get("page_faults"),
        "cgroup_major_page_faults": breakdown.get("major_page_faults"),
        "process_count": sample["process_count"],
        "process_rss_total_bytes": totals["rss_bytes"],
        "process_pss_total_bytes": totals["pss_bytes"],
        "process_uss_total_bytes": totals["uss_bytes"],
    }


def write_csv_sample(sample: Sample, writer: csv.DictWriter) -> None:
    """Write one CSV row per process, or one summary row when none are present."""
    base_row = build_csv_base_row(sample)
    processes = sample["processes"] or [{}]
    for process in processes:
        row = dict(base_row)
        row.update({
            "pid": process.get("pid"),
            "ppid": process.get("ppid"),
            "name": process.get("name"),
            "process_type": process.get("type"),
            "type_source": process.get("type_source"),
            "threads": process.get("threads"),
            "executable": process.get("executable"),
            "cpu_percent": process.get("cpu_percent"),
            "cpu_ticks": process.get("cpu_ticks"),
            "rss_bytes": process.get("rss_bytes"),
            "pss_bytes": process.get("pss_bytes"),
            "uss_bytes": process.get("uss_bytes"),
            "swap_bytes": process.get("swap_bytes"),
            "command": process.get("command"),
        })
        writer.writerow(row)
    sys.stdout.flush()


def build_connection_options(args: argparse.Namespace) -> Dict[str, Any]:
    """Translate command-line authentication options for AsyncSSH."""
    host = args.host
    username = args.username
    password = args.password
    credentials = args.credentials

    if credentials is None and "@" in host:
        credentials, host = host.rsplit("@", 1)
    if credentials is not None:
        if ":" not in credentials:
            raise RuntimeError("--credentials must use username:password format")
        username, password = credentials.split(":", 1)
        if not username:
            raise RuntimeError("username cannot be empty")

    options = {
        "host": host,
        "port": args.port,
        "username": username,
    }
    if args.no_host_key_check:
        options["known_hosts"] = None
    elif args.known_hosts is not None:
        options["known_hosts"] = args.known_hosts
    if password is not None:
        options["password"] = password
    if args.identity is not None:
        options["client_keys"] = [args.identity]
    return options


def selected_target(args: argparse.Namespace) -> Tuple[str, str]:
    """Return the remote selector type and value chosen by the user."""
    if args.pid is not None:
        return "pid", str(args.pid)
    if args.process is not None:
        return "process", args.process
    if args.dobby_container is not None:
        return "dobby", args.dobby_container
    return "cgroup", args.cgroup


def build_remote_command(args: argparse.Namespace) -> str:
    """Build the command which reads the collector from standard input."""
    selector_type, selector = selected_target(args)
    remote_args = [
        "sh", "-s", "--", selector_type, selector,
        "1" if args.mem_breakdown else "0",
        "1" if args.process_stats else "0",
    ]
    return " ".join(shlex.quote(part) for part in remote_args)


def create_csv_writer(enabled: bool) -> Optional[csv.DictWriter]:
    """Create a CSV writer and emit its header when CSV output is selected."""
    if not enabled:
        return None
    writer = csv.DictWriter(sys.stdout, fieldnames=CSV_FIELDS)
    writer.writeheader()
    sys.stdout.flush()
    return writer


def emit_sample(
    sample: Sample,
    args: argparse.Namespace,
    csv_writer: Optional[csv.DictWriter],
) -> None:
    if csv_writer is not None:
        write_csv_sample(sample, csv_writer)
    else:
        display(sample, args.json)


async def stream(args: argparse.Namespace) -> None:
    """Connect once and collect samples until interrupted."""
    connection_options = build_connection_options(args)
    remote_command = build_remote_command(args)
    csv_writer = create_csv_writer(args.csv)
    previous_sample = None  # type: Optional[Sample]
    previous_time = None  # type: Optional[float]

    async with asyncssh.connect(**connection_options) as connection:
        while True:
            result = await connection.run(
                remote_command, input=REMOTE_COLLECTOR_SH, check=False
            )
            sample_time = time.monotonic()
            if result.exit_status and not result.stdout:
                raise RuntimeError(result.stderr.strip() or "remote collector failed")

            sample = parse_collector_output(result.stdout)
            sample["process_stats_enabled"] = args.process_stats
            sample["process_tree_enabled"] = args.process_tree
            elapsed = None if previous_time is None else sample_time - previous_time
            add_cpu_percentages(sample, previous_sample, elapsed)
            emit_sample(sample, args, csv_writer)

            previous_sample = sample
            previous_time = sample_time
            await asyncio.sleep(max(args.interval, 0.1))


def add_target_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("host", help="hostname or username:password@hostname")
    parser.add_argument("cgroup", nargs="?", help="explicit cgroup path")

    discovery = parser.add_argument_group("automatic app discovery")
    discovery.add_argument("--pid", type=int, help="discover cgroup from PID")
    discovery.add_argument("--process", metavar="NAME", help="discover cgroup from process")
    discovery.add_argument(
        "--dobby-container",
        metavar="ID",
        help="discover Dobby cgroup containing this container ID",
    )


def add_ssh_arguments(parser: argparse.ArgumentParser) -> None:
    ssh = parser.add_argument_group("SSH connection")
    ssh.add_argument("-u", "--username")
    ssh.add_argument("-p", "--port", type=int, default=22)
    ssh.add_argument("--identity", help="SSH private-key path")
    ssh.add_argument("--credentials", metavar="USERNAME:PASSWORD")
    ssh.add_argument("--password")
    ssh.add_argument("--known-hosts", help="custom known_hosts file")
    ssh.add_argument(
        "--no-host-key-check",
        action="store_true",
        help="disable host verification (unsafe)",
    )


def add_collection_arguments(parser: argparse.ArgumentParser) -> None:
    collection = parser.add_argument_group("collection")
    collection.add_argument("-i", "--interval", type=float, default=1.0)
    collection.add_argument(
        "--mem-breakdown",
        action="store_true",
        help="include detailed cgroup memory statistics",
    )
    collection.add_argument(
        "--process-tree",
        action="store_true",
        help="display processes in parent-child order",
    )

    process_output = collection.add_mutually_exclusive_group()
    process_output.add_argument(
        "--process-stats",
        dest="process_stats",
        action="store_true",
        help="include per-process statistics (default)",
    )
    process_output.add_argument(
        "--no-process-stats",
        dest="process_stats",
        action="store_false",
        help="skip per-process statistics",
    )
    parser.set_defaults(process_stats=True)


def add_output_arguments(parser: argparse.ArgumentParser) -> None:
    output = parser.add_mutually_exclusive_group()
    output.add_argument("--json", action="store_true", help="output JSON Lines")
    output.add_argument("--csv", action="store_true", help="output CSV rows")


def validate_args(parser: argparse.ArgumentParser, args: argparse.Namespace) -> None:
    selectors = (
        args.cgroup,
        args.pid,
        args.process,
        args.dobby_container,
    )
    if sum(value is not None for value in selectors) != 1:
        parser.error(
            "provide exactly one of: cgroup, --pid, --process, --dobby-container"
        )
    if args.interval <= 0:
        parser.error("--interval must be greater than zero")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    add_target_arguments(parser)
    add_ssh_arguments(parser)
    add_collection_arguments(parser)
    add_output_arguments(parser)

    args = parser.parse_args()
    validate_args(parser, args)
    return args


def main() -> int:
    try:
        asyncio.run(stream(parse_args()))
        return 0
    except KeyboardInterrupt:
        return 130
    except (asyncssh.Error, OSError, RuntimeError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
