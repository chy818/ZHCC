#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
L2 编译器构建脚本 - Python 版本
处理编码和 subprocess 更可靠
"""

import os
import sys
import subprocess
import shutil

PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(PROJECT_ROOT, "src", "compiler_v2")
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "target", "l2_compiler")

MODULES = [
    "runtime.xy",
    "lexer.xy",
    "parser.xy",
    "sema.xy",
    "codegen.xy",
    "utils.xy",
    "main.xy"
]

def main():
    print("=" * 40)
    print("  Building L2 Compiler")
    print("=" * 40)
    print()
    
    # 清理输出目录
    if os.path.exists(OUTPUT_DIR):
        shutil.rmtree(OUTPUT_DIR)
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    ir_files = []
    obj_files = []
    
    # Step 1: 编译每个模块到 IR
    print("[Step 1] Compiling modules to IR...")
    for module in MODULES:
        src_path = os.path.join(SRC_DIR, module)
        ir_path = os.path.join(OUTPUT_DIR, f"{module}.ll")
        
        print(f"  Compiling {module}...")
        
        # 运行 cargo
        result = subprocess.run(
            ["cargo", "run", "--release", "--", src_path, "--ir-pure"],
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            print(f"    ERROR: Failed to compile {module}")
            print(f"    stderr: {result.stderr}")
            return 1
        
        # 过滤 IR 内容 - 只保留真正的 LLVM IR，跳过 cargo 的警告
        lines = result.stdout.splitlines()
        filtered_lines = []
        in_ir = False
        
        for line in lines:
            # 跳过 cargo 的警告和错误信息
            if (line.startswith("cargo:") or 
                line.startswith("warning:") or 
                line.startswith("error:") or 
                line.startswith("   -->") or
                line.startswith("    |") or
                line.startswith("Finished") or
                line.startswith("Compiling") or
                line.startswith("note:")):
                continue
            
            # 检测 IR 开始
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
        
        # 清理开头和结尾的空行
        while filtered_lines and filtered_lines[0].strip() == "":
            filtered_lines.pop(0)
        while filtered_lines and filtered_lines[-1].strip() == "":
            filtered_lines.pop()
        
        # 保存 IR - 使用 UTF-8 无 BOM
        content = "\n".join(filtered_lines)
        with open(ir_path, "w", encoding="utf-8") as f:
            f.write(content)
        
        ir_files.append(ir_path)
        print(f"    OK: {ir_path}")
    
    print()
    
    # Step 2: 编译 IR 到对象文件
    print("[Step 2] Compiling IR to object files...")
    for ir_path in ir_files:
        obj_path = f"{ir_path}.o"
        print(f"  Compiling {os.path.basename(ir_path)}...")
        
        result = subprocess.run(
            ["llc", ir_path, "-filetype=obj", "-o", obj_path],
            capture_output=True,
            text=True
        )
        
        if result.returncode != 0:
            print(f"    ERROR: LLC failed for {ir_path}")
            print(f"    stderr: {result.stderr}")
            return 1
        
        obj_files.append(obj_path)
        print(f"    OK: {obj_path}")
    
    print()
    
    # Step 3: 编译 runtime.c
    print("[Step 3] Compiling runtime.c...")
    runtime_c = os.path.join(PROJECT_ROOT, "runtime", "runtime.c")
    runtime_obj = os.path.join(OUTPUT_DIR, "runtime.c.obj")
    cl_exe = r"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\cl.exe"
    
    result = subprocess.run(
        [cl_exe, "/c", "/nologo", f"/Fo{runtime_obj}", runtime_c],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        print(f"    ERROR: cl.exe failed")
        print(f"    stderr: {result.stderr}")
        return 1
    
    print(f"    OK: {runtime_obj}")
    print()
    
    # Step 4: 链接
    print("[Step 4] Linking...")
    xyc_exe = os.path.join(OUTPUT_DIR, "xyc.exe")
    link_exe = r"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\link.exe"
    
    all_objs = [runtime_obj] + obj_files
    args = [
        link_exe,
        "/SUBSYSTEM:CONSOLE",
        "/ENTRY:main",
        f"/OUT:{xyc_exe}"
    ] + all_objs
    
    result = subprocess.run(
        args,
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
