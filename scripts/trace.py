from pathlib import Path
import argparse
import sys
import runpy
import linecache
import time

import threading

# Handle inputs
parser = argparse.ArgumentParser(
        description="Trace Python function calls."
)

parser.add_argument(
    "-a",
    "--all",
    action="store_true",
    help="Trace all functions"
)

parser.add_argument(
    "-t",
    "--timings",
    action="store_true",
    help="Output time taken for function"
)

parser.add_argument(
    "source",
    type=Path,
    help="Directory containing source files to trace"
)

parser.add_argument(
    "script",
    type=Path,
    help="Python script to execute"
)

parser.add_argument(
    "script_args",
    nargs=argparse.REMAINDER,
    help="Arguments passed to target script"
)

args = parser.parse_args()

SOURCE = args.source.resolve()
SCRIPT = args.script.resolve()

# Global variable for function depth
depth = 0

# Dict for storing function call start times
start_times = {}

# Log prefix
LOG_PREFIX = "[Trace] "

class FuncFrameData:
    def __init__(self, frame, arg):
        self.frame = frame
        self.arg = arg

        self.filename = Path(self.frame.f_code.co_filename)
        self.line = self.frame.f_lineno
        self.name = self.frame.f_code.co_qualname
        self.tid = threading.get_ident()
        self.start_time = time.perf_counter()

    def elapsed(self):
        return (time.perf_counter() - self.start_time) * 1000


def trace_function(frame, event, arg):
    global depth

    

    filename = frame.f_code.co_filename
    file_path = Path(filename).resolve()
    function_name = frame.f_code.co_qualname
    thread_id = threading.get_ident()

    # Only trace real files under source
    if not args.all:
        if not file_path.is_relative_to(SOURCE):
            return trace_function

        # Reject python builtin
        if filename.startswith("<"):
            return trace_function

    try:
        relative_file_path = file_path.relative_to(SOURCE)
    except ValueError:
        relative_file_path = file_path

    call_return = False

    if event == "call":
        start_times[frame] = time.perf_counter()
        call_return = True
        print(
            f"{LOG_PREFIX}" +
            f"[T{thread_id}] " +
            "  " * depth + 
            f"+ {relative_file_path}:{frame.f_lineno}"
            f" {function_name}()"
        )
        depth += 1

    elif event == "return":
        start = start_times.pop(frame, None)
        time_taken = ""
        if start is not None and args.timings:
            elapsed = (time.perf_counter() - start) * 1000
            time_taken = f" [{elapsed:.3}ms]"


        call_return = True
        depth -= 1
        print(
            f"{LOG_PREFIX}" +
            f"[T{thread_id}] " +
            "  " * depth + 
            f"- {relative_file_path}:{frame.f_lineno}"
            f" {function_name}({arg if arg else ""})"
            f"{time_taken}"
        )

    if event == "line" and not call_return and args.all:
        lineno = frame.f_lineno
        line = linecache.getline(filename, lineno)

        print(
            f"{LOG_PREFIX}" +
            f"[T{thread_id}] " +
            "  " * (depth + 1) + 
            f"{relative_file_path}:"
            f"{lineno}"
            f" {line.rstrip().strip(' ')}"
        )

    return trace_function

sys.argv = [str(SCRIPT), *args.script_args]

sys.settrace(trace_function)

runpy.run_path(SCRIPT, run_name="__main__")
