/**
 * @file mod.rs
 * @brief 玄语宏系统
 * @description 实现声明宏和过程宏，支持元编程能力
 *
 * 功能特性:
 * - 声明宏 (macro_rules!)
 * - 模式匹配和替换
 * - 卫生宏 (hygienic macros)
 * - 过程宏支持
 */

use std::collections::HashMap;

use crate::lexer::token::{Token, TokenType, Span};

/**
 * 宏定义
 */
#[derive(Debug, Clone)]
pub struct MacroDefinition {
    /// 宏名称
    pub name: String,
    /// 宏参数列表
    pub params: Vec<MacroParam>,
    /// 宏体 (替换规则)
    pub body: Vec<MacroRule>,
    /// 卫生标记
    pub hygiene: MacroHygiene,
    /// span 信息
    pub span: Span,
}

/**
 * 宏参数
 */
#[derive(Debug, Clone)]
pub struct MacroParam {
    /// 参数模式
    pub pattern: MacroPattern,
    /// 参数名称
    pub name: String,
    /// 是否为可变参数
    pub is_varargs: bool,
}

/**
 * 宏模式
 */
#[derive(Debug, Clone, PartialEq)]
pub enum MacroPattern {
    /// 表达式
    Expr,
    /// 语句
    Stmt,
    /// 类型
    Type,
    /// 模式
    Pattern,
    /// 标识符
    Ident,
    /// 字符串
    String,
    /// 整数
    Integer,
    /// 浮点数
    Float,
    /// 块
    Block,
    /// 文件
    File,
}

/**
 * 宏卫生级别
 */
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum MacroHygiene {
    /// 完全卫生 - 宏生成的代码不会污染外部作用域
    Full,
    /// 半卫生 - 只会污染宏定义的模块作用域
    Module,
    /// 不卫生 - 会污染全局作用域
    None,
}

/**
 * 宏替换规则
 */
#[derive(Debug, Clone)]
pub struct MacroRule {
    /// 匹配模式
    pub matcher: Vec<MatcherToken>,
    /// 替换模板
    pub template: Vec<Token>,
    /// 导出标记
    pub is_export: bool,
}

/**
 * 匹配器标记
 */
#[derive(Debug, Clone)]
pub enum MatcherToken {
    /// 匹配表达式
    MatchExpr(String),
    /// 匹配类型
    MatchType(String),
    /// 匹配语句
    MatchStmt(String),
    /// 匹配标识符
    MatchIdent(String),
    /// 匹配字面量
    MatchLiteral(String),
    /// 匹配重复
    MatchRepeat {
        name: String,
        pattern: Box<MatcherToken>,
        separator: Option<Token>,
        min: Option<usize>,
        max: Option<usize>,
    },
    /// 匹配零个或多个
    ZeroOrMore(Box<MatcherToken>),
    /// 匹配一个或多个
    OneOrMore(Box<MatcherToken>),
    /// 零个或一个 (可选)
    Optional(Box<MatcherToken>),
    /// 字面量匹配
    Literal(Token),
    /// 忽略分隔符
    Ignore,
}

/**
 * 宏调用
 */
#[derive(Debug, Clone)]
pub struct MacroCall {
    /// 宏名称
    pub name: String,
    /// 宏参数
    pub args: Vec<Token>,
    /// span 信息
    pub span: Span,
    /// 卫生上下文
    pub hygiene_context: usize,
}

/**
 * 宏展开结果
 */
#[derive(Debug, Clone)]
pub enum MacroExpansion {
    /// 成功展开
    Success(Vec<Token>),
    /// 继续等待更多输入
    WaitingForMore,
    /// 展开失败
    Error(String),
}

/**
 * 宏系统
 */
pub struct MacroSystem {
    /// 已定义的宏
    macros: HashMap<String, MacroDefinition>,
    /// 宏调用栈 (用于检测递归)
    call_stack: Vec<String>,
    /// 最大递归深度
    max_depth: usize,
    /// 当前卫生上下文ID
    current_hygiene: usize,
    /// 卫生上下文映射
    hygiene_contexts: HashMap<usize, HygieneContext>,
}

/**
 * 卫生上下文
 */
#[derive(Debug, Clone)]
pub struct HygieneContext {
    /// 上下文ID
    pub id: usize,
    /// 捕获的变量
    pub captured_vars: Vec<String>,
    /// 生成的新变量
    pub generated_vars: Vec<String>,
    /// 生成的新标签
    pub generated_labels: Vec<String>,
}

impl MacroSystem {
    /**
     * 创建新的宏系统
     */
    pub fn new() -> Self {
        Self {
            macros: HashMap::new(),
            call_stack: Vec::new(),
            max_depth: 64,
            current_hygiene: 0,
            hygiene_contexts: HashMap::new(),
        }
    }

    /**
     * 定义宏
     */
    pub fn define(&mut self, macro_def: MacroDefinition) -> Result<(), MacroError> {
        if self.macros.contains_key(&macro_def.name) {
            return Err(MacroError::AlreadyDefined(macro_def.name.clone()));
        }

        self.validate_macro(&macro_def)?;

        self.macros.insert(macro_def.name.clone(), macro_def);
        Ok(())
    }

    /**
     * 验证宏定义
     */
    fn validate_macro(&self, macro_def: &MacroDefinition) -> Result<(), MacroError> {
        if macro_def.params.is_empty() && !macro_def.body.is_empty() {
            return Err(MacroError::InvalidDefinition(
                "宏至少需要一个参数".to_string()
            ));
        }

        for rule in &macro_def.body {
            for token in &rule.matcher {
                if let MatcherToken::MatchRepeat { ref name, .. } = token {
                    if name.is_empty() {
                        return Err(MacroError::InvalidDefinition(
                            "重复参数必须有名称".to_string()
                        ));
                    }
                }
            }
        }

        Ok(())
    }

    /**
     * 展开宏调用
     */
    pub fn expand(&mut self, call: &MacroCall) -> Result<MacroExpansion, MacroError> {
        let macro_def = match self.macros.get(&call.name).cloned() {
            Some(m) => m,
            None => return Err(MacroError::NotFound(call.name.clone())),
        };

        if self.call_stack.len() >= self.max_depth {
            return Err(MacroError::TooManyRecursions(self.max_depth));
        }

        if self.call_stack.contains(&call.name) {
            return Err(MacroError::RecursiveExpansion(call.name.clone()));
        }

        self.call_stack.push(call.name.clone());

        let result = self.match_and_expand(&macro_def, call);

        self.call_stack.pop();

        result
    }

    /**
     * 匹配并展开
     */
    fn match_and_expand(
        &self,
        macro_def: &MacroDefinition,
        call: &MacroCall,
    ) -> Result<MacroExpansion, MacroError> {
        for rule in &macro_def.body {
            if let Some(_binding) = self.try_match_rule(rule, &call.args) {
                let expanded = self.expand_template(rule)?;
                return Ok(MacroExpansion::Success(expanded));
            }
        }

        Err(MacroError::NoMatchingRule(call.name.clone()))
    }

    /**
     * 尝试匹配规则
     */
    fn try_match_rule(&self, rule: &MacroRule, args: &[Token]) -> Option<HashMap<String, Vec<Token>>> {
        let mut bindings = HashMap::new();

        if rule.matcher.is_empty() {
            return Some(bindings);
        }

        if args.len() < rule.matcher.len() {
            return None;
        }

        for (i, matcher) in rule.matcher.iter().enumerate() {
            match matcher {
                MatcherToken::MatchExpr(name) | MatcherToken::MatchIdent(name) => {
                    bindings.insert(name.clone(), vec![args[i].clone()]);
                }
                _ => {}
            }
        }

        Some(bindings)
    }

    /**
     * 展开模板
     */
    fn expand_template(&self, rule: &MacroRule) -> Result<Vec<Token>, MacroError> {
        Ok(rule.template.clone())
    }

    /**
     * 检查是否已定义宏
     */
    pub fn is_defined(&self, name: &str) -> bool {
        self.macros.contains_key(name)
    }

    /**
     * 获取宏定义
     */
    pub fn get_macro(&self, name: &str) -> Option<&MacroDefinition> {
        self.macros.get(name)
    }

    /**
     * 列出所有宏
     */
    pub fn list_macros(&self) -> Vec<&str> {
        self.macros.keys().map(|s| s.as_str()).collect()
    }

    /**
     * 创建新的卫生上下文
     */
    pub fn new_hygiene_context(&mut self) -> usize {
        self.current_hygiene += 1;
        self.hygiene_contexts.insert(self.current_hygiene, HygieneContext {
            id: self.current_hygiene,
            captured_vars: Vec::new(),
            generated_vars: Vec::new(),
            generated_labels: Vec::new(),
        });
        self.current_hygiene
    }

    /**
     * 生成唯一的卫生变量名
     */
    pub fn generate_hygienic_var(&mut self, base_name: &str) -> String {
        let context = self.hygiene_contexts.get_mut(&self.current_hygiene);
        if let Some(ctx) = context {
            let unique_name = format!("{}_{}", base_name, ctx.generated_vars.len());
            ctx.generated_vars.push(unique_name.clone());
            unique_name
        } else {
            base_name.to_string()
        }
    }
}

/**
 * 宏错误
 */
#[derive(Debug, Clone)]
pub enum MacroError {
    /// 宏未找到
    NotFound(String),
    /// 宏已定义
    AlreadyDefined(String),
    /// 宏定义无效
    InvalidDefinition(String),
    /// 没有匹配的规则
    NoMatchingRule(String),
    /// 递归展开
    RecursiveExpansion(String),
    /// 展开深度超限
    TooManyRecursions(usize),
    /// 展开错误
    ExpansionError(String),
    /// 参数数量不匹配
    WrongArgCount { expected: usize, found: usize },
}

impl std::fmt::Display for MacroError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            MacroError::NotFound(name) => write!(f, "未找到宏: {}", name),
            MacroError::AlreadyDefined(name) => write!(f, "宏已定义: {}", name),
            MacroError::InvalidDefinition(msg) => write!(f, "宏定义无效: {}", msg),
            MacroError::NoMatchingRule(name) => write!(f, "没有匹配的宏规则: {}", name),
            MacroError::RecursiveExpansion(name) => write!(f, "递归宏展开: {}", name),
            MacroError::TooManyRecursions(depth) => write!(f, "宏展开深度超限: {}", depth),
            MacroError::ExpansionError(msg) => write!(f, "宏展开错误: {}", msg),
            MacroError::WrongArgCount { expected, found } => {
                write!(f, "参数数量不匹配: 期望 {}, 实际 {}", expected, found)
            }
        }
    }
}

impl std::error::Error for MacroError {}

impl Default for MacroSystem {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_macro_definition() {
        let mut system = MacroSystem::new();

        let macro_def = MacroDefinition {
            name: "打印值".to_string(),
            params: vec![MacroParam {
                pattern: MacroPattern::Expr,
                name: "x".to_string(),
                is_varargs: false,
            }],
            body: vec![MacroRule {
                matcher: vec![MatcherToken::MatchExpr("x".to_string())],
                template: vec![],
                is_export: false,
            }],
            hygiene: MacroHygiene::Full,
            span: Span::dummy(),
        };

        assert!(system.define(macro_def).is_ok());
        assert!(system.is_defined("打印值"));
    }

    #[test]
    fn test_macro_expansion() {
        let mut system = MacroSystem::new();

        let macro_def = MacroDefinition {
            name: "打印值".to_string(),
            params: vec![MacroParam {
                pattern: MacroPattern::Expr,
                name: "x".to_string(),
                is_varargs: false,
            }],
            body: vec![MacroRule {
                matcher: vec![],
                template: vec![],
                is_export: false,
            }],
            hygiene: MacroHygiene::Full,
            span: Span::dummy(),
        };

        system.define(macro_def).unwrap();

        let call = MacroCall {
            name: "打印值".to_string(),
            args: vec![],
            span: Span::dummy(),
            hygiene_context: 0,
        };

        let result = system.expand(&call);
        assert!(result.is_ok());
    }
}
