/**
 * @file sema.rs
 * @brief CCAS 语义分析器 (Semantic Analyzer)
 * @description 类型检查、作用域分析、符号解析
 * 
 * 功能:
 * - 变量声明类型检查
 * - 函数调用类型匹配
 * - 作用域嵌套检查
 * - 自动类型推断
 */

use crate::ast::*;
use crate::lexer::token::Span;
use crate::error::{TypeError, CompilerError};

/**
 * 符号信息
 */
#[derive(Debug, Clone)]
pub struct Symbol {
    pub name: String,
    pub symbol_type: Type,
    pub is_mutable: bool,
    pub span: Span,
}

/**
 * 作用域
 */
#[derive(Debug, Clone)]
pub struct Scope {
    parent: Option<usize>,
    symbols: std::collections::HashMap<String, Symbol>,
}

impl Scope {
    pub fn new(parent: Option<usize>) -> Self {
        Self {
            parent,
            symbols: std::collections::HashMap::new(),
        }
    }

    pub fn define(&mut self, name: String, symbol: Symbol) {
        self.symbols.insert(name, symbol);
    }

    pub fn lookup(&self, name: &str) -> Option<&Symbol> {
        self.symbols.get(name).or_else(|| {
            if let Some(parent_idx) = self.parent {
                None // 简化处理，实际需要递归查找
            } else {
                None
            }
        })
    }
}

/**
 * 语义分析器
 */
pub struct SemanticAnalyzer {
    scopes: Vec<Scope>,
    errors: Vec<TypeError>,
}

impl SemanticAnalyzer {
    pub fn new() -> Self {
        let mut scopes = Vec::new();
        scopes.push(Scope::new(None)); // 全局作用域
        Self { scopes, errors: Vec::new() }
    }

    /**
     * 进入新作用域
     */
    fn enter_scope(&mut self) {
        let parent = Some(self.scopes.len() - 1);
        self.scopes.push(Scope::new(parent));
    }

    /**
     * 退出作用域
     */
    fn exit_scope(&mut self) {
        self.scopes.pop();
    }

    /**
     * 定义符号
     */
    fn define_symbol(&mut self, name: String, symbol_type: Type, is_mutable: bool, span: Span) {
        let scope_idx = self.scopes.len() - 1;
        let name_clone = name.clone();
        self.scopes[scope_idx].define(name, Symbol {
            name: name_clone,
            symbol_type,
            is_mutable,
            span,
        });
    }

    /**
     * 查找符号
     */
    fn lookup_symbol(&self, name: &str) -> Option<&Symbol> {
        for scope in self.scopes.iter().rev() {
            if let Some(symbol) = scope.lookup(name) {
                return Some(symbol);
            }
        }
        None
    }

    /**
     * 报告错误
     */
    fn error(&mut self, message: String, span: Span) {
        self.errors.push(TypeError {
            code: "CCAS-T001".to_string(),
            message,
            span,
        });
    }

    /**
     * 验证模块
     */
    pub fn analyze_module(&mut self, module: &Module) -> Result<(), Vec<TypeError>> {
        // 首先收集所有函数声明到全局作用域
        for func in &module.functions {
            self.define_symbol(
                func.name.clone(),
                func.return_type.clone(),
                false,
                func.span,
            );
        }

        // 验证每个函数
        for func in &module.functions {
            self.analyze_function(func)?;
        }

        if self.errors.is_empty() {
            Ok(())
        } else {
            Err(std::mem::take(&mut self.errors))
        }
    }

    /**
     * 验证函数
     */
    fn analyze_function(&mut self, func: &Function) -> Result<(), Vec<TypeError>> {
        // 进入函数作用域
        self.enter_scope();

        // 添加函数参数到作用域
        for param in &func.params {
            self.define_symbol(
                param.name.clone(),
                param.param_type.clone(),
                false,
                Span::dummy(),
            );
        }

        // 分析函数体
        for stmt in &func.body.statements {
            self.analyze_statement(stmt)?;
        }

        // 退出函数作用域
        self.exit_scope();

        Ok(())
    }

    /**
     * 验证语句
     */
    fn analyze_statement(&mut self, stmt: &Stmt) -> Result<Type, Vec<TypeError>> {
        match stmt {
            Stmt::Let(let_stmt) => {
                self.analyze_let_statement(let_stmt)?;
                Ok(Type::Void)
            }
            Stmt::Return(return_stmt) => {
                self.analyze_return_statement(return_stmt)
            }
            Stmt::If(if_stmt) => {
                self.analyze_if_statement(if_stmt)
            }
            Stmt::Loop(loop_stmt) => {
                self.analyze_loop_statement(loop_stmt)
            }
            Stmt::Expr(expr_stmt) => {
                self.analyze_expression(&expr_stmt.expr)?;
                Ok(Type::Void)
            }
            Stmt::Block(block_stmt) => {
                self.enter_scope();
                for s in &block_stmt.statements {
                    self.analyze_statement(s)?;
                }
                self.exit_scope();
                Ok(Type::Void)
            }
            Stmt::Break(_) | Stmt::Continue(_) => {
                Ok(Type::Void)
            }
            Stmt::Assignment(assign_stmt) => {
                self.analyze_assignment_statement(assign_stmt)
            }
        }
    }

    /**
     * 验证变量声明语句
     */
    fn analyze_let_statement(&mut self, let_stmt: &LetStmt) -> Result<(), Vec<TypeError>> {
        // 分析初始化表达式
        if let Some(init) = &let_stmt.initializer {
            let init_type = self.analyze_expression(init)?;

            // 检查类型标注
            if let Some(type_annotation) = &let_stmt.type_annotation {
                if !init_type.can_cast_to(type_annotation) {
                    self.error(
                        format!("类型不匹配: 期望 {:?}, 但找到 {:?}", type_annotation, init_type),
                        let_stmt.span,
                    );
                }
            }
        } else if let_stmt.type_annotation.is_none() {
            // 需要类型标注或初始化值
            self.error(
                "变量声明需要类型标注或初始化值".to_string(),
                let_stmt.span,
            );
        }

        // 定义符号
        let var_type = let_stmt.type_annotation.clone().unwrap_or(Type::Int);
        self.define_symbol(
            let_stmt.name.clone(),
            var_type,
            false, // TODO: 支持可变
            let_stmt.span,
        );

        Ok(())
    }

    /**
     * 验证返回语句
     */
    fn analyze_return_statement(&mut self, return_stmt: &ReturnStmt) -> Result<Type, Vec<TypeError>> {
        if let Some(value) = &return_stmt.value {
            self.analyze_expression(value)
        } else {
            Ok(Type::Void)
        }
    }

    /**
     * 验证 if 语句
     */
    fn analyze_if_statement(&mut self, if_stmt: &IfStmt) -> Result<Type, Vec<TypeError>> {
        for branch in &if_stmt.branches {
            let cond_type = self.analyze_expression(&branch.condition)?;
            
            // 条件必须是布尔类型
            if cond_type != Type::Bool {
                self.error(
                    format!("if 条件必须是布尔类型，但找到 {:?}", cond_type),
                    branch.condition.span(),
                );
            }

            self.analyze_statement(&branch.body)?;
        }

        if let Some(else_branch) = &if_stmt.else_branch {
            self.analyze_statement(else_branch)?;
        }

        Ok(Type::Void)
    }

    /**
     * 验证循环语句
     */
    fn analyze_loop_statement(&mut self, loop_stmt: &LoopStmt) -> Result<Type, Vec<TypeError>> {
        // 处理计数循环 - 自动定义循环变量
        if let Some(counter) = &loop_stmt.counter {
            // 定义循环变量
            self.define_symbol(
                counter.variable.clone(),
                Type::Int,
                true,
                loop_stmt.span,
            );
        }
        
        if let Some(cond) = &loop_stmt.condition {
            let cond_type = self.analyze_expression(cond)?;
            if cond_type != Type::Bool {
                self.error(
                    format!("循环条件必须是布尔类型，但找到 {:?}", cond_type),
                    cond.span(),
                );
            }
        }

        self.analyze_statement(&loop_stmt.body)
    }

    /**
     * 验证赋值语句
     */
    fn analyze_assignment_statement(&mut self, assign_stmt: &AssignmentStmt) -> Result<Type, Vec<TypeError>> {
        // 检查左值
        if let Expr::Identifier(ident) = &assign_stmt.target {
            let symbol = self.lookup_symbol(&ident.name);
            if symbol.is_none() {
                self.error(
                    format!("未定义的变量: {}", ident.name),
                    ident.span,
                );
            }
        }

        let value_type = self.analyze_expression(&assign_stmt.value)?;
        
        // TODO: 检查赋值类型兼容性
        
        Ok(Type::Void)
    }

    /**
     * 验证表达式
     */
    fn analyze_expression(&self, expr: &Expr) -> Result<Type, Vec<TypeError>> {
        match expr {
            Expr::Identifier(ident) => {
                // 查找符号
                let symbol = self.lookup_symbol(&ident.name);
                match symbol {
                    Some(s) => Ok(s.symbol_type.clone()),
                    None => {
                        Err(vec![TypeError {
                            code: "CCAS-T002".to_string(),
                            message: format!("未定义的变量: {}", ident.name),
                            span: ident.span,
                        }])
                    }
                }
            }
            Expr::Literal(lit) => {
                Ok(lit.kind.type_info())
            }
            Expr::Binary(binary) => {
                self.analyze_binary_expression(binary)
            }
            Expr::Unary(unary) => {
                self.analyze_unary_expression(unary)
            }
            Expr::Call(call) => {
                self.analyze_call_expression(call)
            }
            Expr::MemberAccess(member) => {
                self.analyze_member_expression(member)
            }
            Expr::Grouped(expr) => {
                self.analyze_expression(expr)
            }
        }
    }

    /**
     * 验证二元表达式
     */
    fn analyze_binary_expression(&self, binary: &BinaryExpr) -> Result<Type, Vec<TypeError>> {
        let left_type = self.analyze_expression(&binary.left)?;
        let right_type = self.analyze_expression(&binary.right)?;

        match binary.op {
            // 算术运算
            BinaryOp::Add | BinaryOp::Sub | BinaryOp::Mul | BinaryOp::Div | BinaryOp::Rem => {
                // 左右类型必须相同且为数值类型
                if left_type != right_type {
                    return Err(vec![TypeError {
                        code: "CCAS-T003".to_string(),
                        message: format!("算术运算需要相同类型，但左边是 {:?}，右边是 {:?}", left_type, right_type),
                        span: binary.span,
                    }]);
                }
                Ok(left_type)
            }
            // 比较运算
            BinaryOp::Eq | BinaryOp::Ne | BinaryOp::Gt | BinaryOp::Lt | BinaryOp::Ge | BinaryOp::Le => {
                Ok(Type::Bool)
            }
            // 逻辑运算
            BinaryOp::And | BinaryOp::Or => {
                if left_type != Type::Bool || right_type != Type::Bool {
                    return Err(vec![TypeError {
                        code: "CCAS-T004".to_string(),
                        message: "逻辑运算需要布尔类型".to_string(),
                        span: binary.span,
                    }]);
                }
                Ok(Type::Bool)
            }
            // 位运算
            BinaryOp::BitAnd | BinaryOp::BitOr | BinaryOp::BitXor | BinaryOp::Shl | BinaryOp::Shr => {
                Ok(left_type)
            }
            // 赋值
            BinaryOp::Assign => {
                Ok(right_type)
            }
        }
    }

    /**
     * 验证一元表达式
     */
    fn analyze_unary_expression(&self, unary: &UnaryExpr) -> Result<Type, Vec<TypeError>> {
        let operand_type = self.analyze_expression(&unary.operand)?;

        match unary.op {
            UnaryOp::Neg => {
                // 负号只能用于数值类型
                if !operand_type.is_numeric() {
                    return Err(vec![TypeError {
                        code: "CCAS-T005".to_string(),
                        message: format!("负号只能用于数值类型，但找到 {:?}", operand_type),
                        span: unary.span,
                    }]);
                }
                Ok(operand_type)
            }
            UnaryOp::Not => {
                // 逻辑非只能用于布尔类型
                if operand_type != Type::Bool {
                    return Err(vec![TypeError {
                        code: "CCAS-T006".to_string(),
                        message: format!("非运算只能用于布尔类型，但找到 {:?}", operand_type),
                        span: unary.span,
                    }]);
                }
                Ok(Type::Bool)
            }
            UnaryOp::BitNot => {
                // 位非只能用于整数类型
                if !operand_type.is_integer() {
                    return Err(vec![TypeError {
                        code: "CCAS-T007".to_string(),
                        message: format!("位非只能用于整数类型，但找到 {:?}", operand_type),
                        span: unary.span,
                    }]);
                }
                Ok(operand_type)
            }
        }
    }

    /**
     * 验证函数调用表达式
     */
    fn analyze_call_expression(&self, call: &CallExpr) -> Result<Type, Vec<TypeError>> {
        // 分析函数名表达式
        if let Expr::Identifier(ident) = &*call.function {
            // 检查是否为内置函数
            match ident.name.as_str() {
                "打印" | "print" => {
                    // 打印函数，返回 Void
                    return Ok(Type::Void);
                }
                _ => {}
            }
            
            // 查找函数
            let symbol = self.lookup_symbol(&ident.name);
            if symbol.is_none() {
                return Err(vec![TypeError {
                    code: "CCAS-T008".to_string(),
                    message: format!("未定义的函数: {}", ident.name),
                    span: ident.span,
                }]);
            }
        }

        // TODO: 检查参数类型匹配
        
        Ok(Type::Int) // 简化返回 int
    }

    /**
     * 验证成员访问表达式
     */
    fn analyze_member_expression(&self, member: &MemberAccessExpr) -> Result<Type, Vec<TypeError>> {
        // 简化处理
        Ok(Type::Int)
    }
}

impl Default for SemanticAnalyzer {
    fn default() -> Self {
        Self::new()
    }
}

/**
 * 类型辅助方法
 */
trait TypeExt {
    fn can_cast_to(&self, target: &Type) -> bool;
    fn is_numeric(&self) -> bool;
    fn is_integer(&self) -> bool;
}

impl TypeExt for Type {
    fn can_cast_to(&self, target: &Type) -> bool {
        match (self, target) {
            (Type::Int, Type::Long) => true,
            (Type::Int, Type::Float) => true,
            (Type::Int, Type::Double) => true,
            (Type::Long, Type::Float) => true,
            (Type::Long, Type::Double) => true,
            (Type::Float, Type::Double) => true,
            _ => self == target,
        }
    }

    fn is_numeric(&self) -> bool {
        matches!(self, Type::Int | Type::Long | Type::Float | Type::Double)
    }

    fn is_integer(&self) -> bool {
        matches!(self, Type::Int | Type::Long)
    }
}

/**
 * 字面量类型推断
 */
impl LiteralKind {
    pub fn type_info(&self) -> Type {
        match self {
            LiteralKind::Integer(_) => Type::Int,
            LiteralKind::Float(_) => Type::Float,
            LiteralKind::String(_) => Type::String,
            LiteralKind::Char(_) => Type::Char,
            LiteralKind::Boolean(_) => Type::Bool,
        }
    }
}

/**
 * 语义分析入口函数
 */
pub fn analyze(module: &Module) -> Result<(), Vec<TypeError>> {
    let mut analyzer = SemanticAnalyzer::new();
    analyzer.analyze_module(module)
}
