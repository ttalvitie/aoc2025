#!/usr/bin/env python3

import multiprocessing.pool
import os
import subprocess
import tempfile
from pathlib import Path


def build_asm_file(paths: tuple[Path, Path]) -> None:
    (src_path, object_path) = paths
    subprocess.check_call(
        [
            "nasm",
            "-f",
            "elf32",
            "-g",
            "-F",
            "dwarf",
            "-i",
            str(src_path.parent),
            str(src_path),
            "-o",
            str(object_path),
        ]
    )


def link_binary(paths: tuple[list[Path], Path]) -> None:
    (object_paths, binary_path) = paths
    subprocess.check_call(
        ["ld", "-m", "elf_i386", *map(str, object_paths), "-o", str(binary_path)]
    )


def build() -> None:
    root_dir = Path(os.path.dirname(os.path.abspath(__file__)))
    src_dir = root_dir / "src"
    bin_dir = root_dir / "bin"

    main_srcs = []
    common_srcs = []
    for filename in os.listdir(src_dir):
        if filename.endswith(".asm"):
            if filename.startswith("main_"):
                main_srcs.append(filename)
            else:
                common_srcs.append(filename)

    with tempfile.TemporaryDirectory() as tmp_dir_str:
        tmp_dir = Path(tmp_dir_str)
        with multiprocessing.pool.ThreadPool(4) as pool:
            pool.map(
                build_asm_file,
                [
                    (src_dir / src_name, tmp_dir / (src_name + ".o"))
                    for src_name in main_srcs + common_srcs
                ],
            )
            pool.map(
                link_binary,
                [
                    (
                        [
                            tmp_dir / (src_name + ".o")
                            for src_name in common_srcs + [main_src_name]
                        ],
                        bin_dir / main_src_name[5:-4],
                    )
                    for main_src_name in main_srcs
                ],
            )


if __name__ == "__main__":
    build()
