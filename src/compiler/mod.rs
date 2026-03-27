/**
 * @file mod.rs
 * @brief 编译器核心模块
 */

pub mod incremental;

pub use incremental::{
    IncrementalCompiler, IncrementalResult, CompileTask,
    FileChange, ModuleInfo, BuildStats,
};
