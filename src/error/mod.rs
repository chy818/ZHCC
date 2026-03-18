/**
 * @file mod.rs
 * @brief CCAS 错误处理模块
 */

pub mod error;

pub use error::{CompilerError, ParserError, TypeError, CodegenError, report_error};
