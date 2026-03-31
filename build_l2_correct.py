#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
正确的 L2 编译器构建脚本
只编译 main.xy，因为它已经 import 了所有其他模块
"""

import os
import sys
import subprocess
import shutil

PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(PROJECT_ROOT, "src", "compiler_v2")
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "target", "l2_compiler")

def main():
    print("=" * 40)
    print("  Building L2 Compiler (Correct Way)")
    print("=" * 40)
    print()
    
    # 清理输出目录
    if os.path.exists(OUTPUT_DIR):
        shutil.rmtree(OUTPUT_DIR)
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    # Step 1: 只编译 main.xy（它 import 了所有其他模块）
    print("[Step 1] Compiling main.xy...")
    src_path = os.path.join(SRC_DIR, "main.xy")
    ir_path = os.path.join(OUTPUT_DIR, "main.ll")
    
    # 运行 cargo
    result = subprocess.run(
        ["cargo", "run", "--release", "--", src_path, "--ir-pure"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="ignore"
    )
    
    if result.returncode != 0:
        print(f"    ERROR: Failed to compile main.xy")
        print(f"    stderr: {result.stderr}")
        return 1
    
    # 过滤 IR 内容
    lines = result.stdout.splitlines()
    filtered_lines = []
    in_ir = False
    
    for line in lines:
        if (line.startswith("cargo:") or 
            line.startswith("warning:") or 
            line.startswith("error:") or 
            line.startswith("   -->") or
            line.startswith("    |") or
            line.startswith("Finished") or
            line.startswith("Compiling") or
            line.startswith("note:")):
            continue
        
        if (line.startswith("declare ") or 
            line.startswith("define ") or 
            line.startswith("@") or 
            line.startswith("!") or
            line.startswith("source_filename") or
            line.startswith("dso_local") or
            line.startswith("target ") or
            line.startswith("attributes") or
            line.startswith("%")):
            in_ir = True
        
        if in_ir:
            filtered_lines.append(line)
    
    # 清理空行
    while filtered_lines and filtered_lines[0].strip() == "":
        filtered_lines.pop(0)
    while filtered_lines and filtered_lines[-1].strip() == "":
        filtered_lines.pop()
    
    # 保存 IR
    content = "\n".join(filtered_lines)
    with open(ir_path, "w", encoding="utf-8") as f:
        f.write(content)
    
    print(f"    OK: {ir_path}")
    print()
    
    # Step 2: 编译 IR 到对象文件
    print("[Step 2] Compiling IR to object file...")
    obj_path = os.path.join(OUTPUT_DIR, "main.o")
    
    result = subprocess.run(
        ["llc", ir_path, "-filetype=obj", "-o", obj_path],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        print(f"    ERROR: LLC failed")
        print(f"    stderr: {result.stderr}")
        return 1
    
    print(f"    OK: {obj_path}")
    print()
    
    # Step 3: 编译 runtime.c
    print("[Step 3] Compiling runtime.c...")
    runtime_c = os.path.join(PROJECT_ROOT, "runtime", "runtime.c")
    runtime_obj = os.path.join(OUTPUT_DIR, "runtime.o")
    
    # 使用 clang 编译 runtime.c
    result = subprocess.run(
        ["clang", "-c", runtime_c, "-o", runtime_obj],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        print(f"    ERROR: clang failed for runtime.c")
        print(f"    stderr: {result.stderr}")
        return 1
    
    print(f"    OK: {runtime_obj}")
    print()
    
    # Step 4: 链接
    print("[Step 4] Linking...")
    xyc_exe = os.path.join(OUTPUT_DIR, "xyc.exe")
    
    result = subprocess.run(
        ["clang", runtime_obj, obj_path, "-o", xyc_exe],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        print(f"    ERROR: Link failed")
        print(f"    stdout: {result.stdout}")
        print(f"    stderr: {result.stderr}")
        return 1
    
    print(f"    OK: {xyc_exe}")
    print()
    print("=" * 40)
    print("  L2 Compiler Build Success!")
    print("=" * 40)
    print(f"Executable: {xyc_exe}")
    print()
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
