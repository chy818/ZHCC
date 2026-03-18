/**
 * @file main.rs
 * @brief CCAS 中文计算体系编译器 (zhcc) 主程序入口
 * @description 编译器命令行工具，用于编译 .zh 源文件
 */

use std::env;
use std::fs;
use std::process;

fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        print_usage(&args[0]);
        process::exit(1);
    }

    let filename = &args[1];

    // 读取源文件
    let source = match fs::read_to_string(filename) {
        Ok(content) => content,
        Err(e) => {
            eprintln!("错误: 无法读取文件 '{}': {}", filename, e);
            process::exit(1);
        }
    };

    println!("正在编译: {}", filename);
    println!("源文件大小: {} 字节", source.len());

    // ========== 词法分析 ==========
    println!("\n=== 词法分析 ===");
    let mut lexer = zhcc::Lexer::new(source);
    
    let tokens = match lexer.tokenize() {
        Ok(t) => t,
        Err(e) => {
            eprintln!("词法错误 [{}]: {}", e.code, e.message);
            eprintln!("  位置: 行 {}, 列 {}", e.span.start_line, e.span.start_column);
            process::exit(1);
        }
    };
    
    println!("词法分析完成，共 {} 个 Token", tokens.len());

    // 打印前 10 个 Token (调试用)
    for (i, token) in tokens.iter().take(10).enumerate() {
        if token.token_type == zhcc::TokenType::文件结束 {
            break;
        }
        println!("  {:4}: {:?}", i + 1, token);
    }

    // ========== 语法分析 ==========
    println!("\n=== 语法分析 ===");
    let ast = match zhcc::parse(tokens) {
        Ok(m) => m,
        Err(e) => {
            eprintln!("语法错误 [{}]: {}", e.code, e.message);
            eprintln!("  位置: 行 {}, 列 {}", e.span.start_line, e.span.start_column);
            process::exit(1);
        }
    };

    println!("语法分析完成");
    println!("  函数数量: {}", ast.functions.len());
    
    for func in &ast.functions {
        println!("    - {} (参数: {}, 返回类型: {:?})", 
            func.name, 
            func.params.len(),
            func.return_type
        );
    }

    // ========== 语义分析 ==========
    println!("\n=== 语义分析 ===");
    match zhcc::analyze(&ast) {
        Ok(()) => {
            println!("语义分析完成，无错误");
        }
        Err(errors) => {
            eprintln!("语义错误 ({} 个):", errors.len());
            for error in &errors {
                eprintln!("  [{}]: {}", error.code, error.message);
                eprintln!("    位置: 行 {}, 列 {}", error.span.start_line, error.span.start_column);
            }
            process::exit(1);
        }
    }

    // ========== 代码生成 ==========
    println!("\n=== 代码生成 ===");
    let ir = match zhcc::generate_ir(&ast) {
        Ok(ir) => ir,
        Err(e) => {
            eprintln!("代码生成错误 [{}]: {}", e.code, e.message);
            process::exit(1);
        }
    };

    println!("代码生成完成");
    println!("\n--- LLVM IR ---");
    println!("{}", ir);

    println!("\n编译成功!");
}

fn print_usage(program: &str) {
    println!("CCAS 中文计算体系编译器 (zhcc) v0.1.0");
    println!();
    println!("用法: {} <源文件>", program);
    println!();
    println!("选项:");
    println!("  -h, --help    显示此帮助信息");
    println!();
    println!("示例:");
    println!("  {} hello.zh   编译 hello.zh 源文件", program);
}
