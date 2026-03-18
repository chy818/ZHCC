/**
 * @file mod.rs
 * @brief CCAS 词法分析器模块
 * @description 词法分析器模块入口，包含 Token 和 Lexer
 */

pub mod token;
pub mod lexer;

pub use token::{Token, TokenType, Keyword, Span, lookup_keyword, is_keyword, is_boolean_literal, keyword_count};
pub use lexer::{Lexer, LexerError};
