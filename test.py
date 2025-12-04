#!/usr/bin/env python3

import multiprocessing.pool
import os
import subprocess
import sys
import tempfile
import threading
from dataclasses import dataclass
from pathlib import Path

import build


@dataclass
class Job:
    name: str
    binary_name: str
    input_path: Path
    output_path: Path
    binary_path: Path
    print_lock: threading.Lock


def log(s: str, lock=None) -> None:
    if lock is None:
        print(s, file=sys.stderr)
    else:
        lock.acquire()
        try:
            print(s, file=sys.stderr)
        finally:
            lock.release()


def run_test_job(job: Job) -> bool:
    with tempfile.TemporaryDirectory() as tmp_dir_str:
        tmp_dir = Path(tmp_dir_str)
        with job.input_path.open() as in_fp, (tmp_dir / "output").open("w") as out_fp:
            status = subprocess.call([job.binary_path], stdin=in_fp, stdout=out_fp)

        if status == 0:
            try:
                diff = subprocess.check_output(
                    ["diff", job.output_path, str(tmp_dir / "output")]
                )
                assert len(diff) == 0
                log(
                    f"SUCCESS: Test '{job.name}' for binary '{job.binary_name}'",
                    job.print_lock,
                )
                return True
            except subprocess.CalledProcessError as e:
                diff = e.output.decode("UTF-8")
                log(
                    f"FAILURE: Test '{job.name}' for binary '{job.binary_name}' failed due to mismatch in output. Diff:\n{diff}",
                    job.print_lock,
                )
                return False
        else:
            log(
                f"FAILURE: Test '{job.name}' for binary '{job.binary_name}' failed due to nonzero exit status {status}",
                job.print_lock,
            )
            return False

        # Unreachable
        assert False


def test() -> int:
    root_dir = Path(os.path.dirname(os.path.abspath(__file__)))
    bin_dir = root_dir / "bin"
    data_dir = root_dir / "data"

    input_files = set()
    output_files = set()
    for filename in os.listdir(data_dir):
        if filename.endswith(".in"):
            input_files.add(filename[:-3])
        elif filename.endswith(".out"):
            output_files.add(filename[:-4])
        else:
            log(f"ERROR: Unrecognized file '{filename}' in the data directory")
            sys.exit(1)

    extra_output_files = set.difference(output_files, input_files)
    if len(extra_output_files) > 0:
        log(
            f"ERROR: Output file '{next(iter(extra_output_files))}.out' in the data directory does not have a corresponding input file"
        )
        sys.exit(1)

    extra_input_files = set.difference(input_files, output_files)
    if len(extra_input_files) > 0:
        log(
            f"ERROR: Input file '{next(iter(extra_input_files))}.in' in the data directory does not have a corresponding output file"
        )
        sys.exit(1)

    print_lock = threading.Lock()

    jobs = []
    for name in input_files:
        binary_name = name
        if "_" in name:
            binary_name = name[: name.index("_")]
        job = Job(
            name,
            binary_name,
            data_dir / (name + ".in"),
            data_dir / (name + ".out"),
            bin_dir / binary_name,
            print_lock,
        )
        if not job.binary_path.is_file():
            log(
                f"ERROR: Binary named '{binary_name}' required by input '{name}.in' does not exist in the bin directory"
            )
            sys.exit(1)
        jobs.append(job)

    with multiprocessing.pool.ThreadPool(4) as pool:
        results = pool.map(run_test_job, jobs)

    success = all(results)
    log(
        f"\n{'SUCCESS' if success else 'FAILURE'}: {sum(map(int, results))} out of {len(results)} tests succeeded"
    )
    return int(not success)


if __name__ == "__main__":
    build.build()
    sys.exit(test())
