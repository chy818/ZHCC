/**
 * @file error.rs
 * @brief CCAS 编译器错误处理
 * @description 定义编译错误类型和错误报告
 */

use crate::lexer::token::Span;
use crate::lexer::LexerError;

/**
 * 重新导出 Span 用于方便访问
 */
pub use crate::lexer::token::Span as SpanHelper;

/**
 * 编译器错误类型
 */
#[derive(Debug, Clone)]
pub enum CompilerError {
    /**
     * 词法分析错误
     */
    Lexer(LexerError),

    /**
     * 语法分析错误
     */
    Parser(ParserError),

    /**
     * 类型错误
     */
    Type(TypeError),

    /**
     * 代码生成错误
     */
    Codegen(CodegenError),
}

/**
 * 语法分析错误
 */
#[derive(Debug, Clone)]
pub struct ParserError {
    pub code: String,
    pub message: String,
    pub span: Span,
}

impl ParserError {
    pub fn unexpected_token(expected: &str, found: &str, span: Span) -> Self {
        Self {
            code: "CCAS-P001".to_string(),
            message: format!("期望 {}, 但遇到 {}", expected, found),
            span,
        }
    }

    pub fn unexpected_token_at(line: usize, col: usize, message: &str) -> Self {
        Self {
            code: "CCAS-P001".to_string(),
            message: message.to_string(),
            span: Span::new(line, col, line, col),
        }
    }
}

/**
 * 类型错误
 */
#[derive(Debug, Clone)]
pub struct TypeError {
    pub code: String,
    pub message: String,
    pub span: Span,
}

impl TypeError {
    pub fn type_mismatch(expected: &str, found: &str, span: Span) -> Self {
        Self {
            code: "CCAS-T001".to_string(),
            message: format!("类型不匹配: 期望 {}, 但找到 {}", expected, found),
            span,
        }
    }

    pub fn unknown_type(type_name: &str, span: Span) -> Self {
        Self {
            code: "CCAS-T002".to_string(),
            message: format!("未知的类型: {}", type_name),
            span,
        }
    }
}

/**
 * 代码生成错误
 */
#[derive(Debug, Clone)]
pub struct CodegenError {
    pub code: String,
    pub message: String,
}

impl CodegenError {
    pub fn unsupported_feature(feature: &str) -> Self {
        Self {
            code: "CCAS-C001".to_string(),
            message: format!("不支持的功能: {}", feature),
        }
    }
}

/**
 * 错误报告
 */
pub fn report_error(error: &CompilerError) {
    match error {
        CompilerError::Lexer(e) => {
            eprintln!("词法错误 [{}]: {} (行 {}, 列 {})", 
                e.code, e.message, e.span.start_line, e.span.start_column);
        }
        CompilerError::Parser(e) => {
            eprintln!("语法错误 [{}]: {} (行 {}, 列 {})", 
                e.code, e.message, e.span.start_line, e.span.start_column);
        }
        CompilerError::Type(e) => {
            eprintln!("类型错误 [{}]: {} (行 {}, 列 {})", 
                e.code, e.message, e.span.start_line, e.span.start_column);
        }
        CompilerError::Codegen(e) => {
            eprintln!("代码生成错误 [{}]: {}", e.code, e.message);
        }
    }
}
