/**
 * @file codegen.rs
 * @brief CCAS 代码生成器
 * @description 将 AST 转换为 LLVM IR 代码
 * 
 * 功能:
 * - 模块定义生成
 * - 函数定义和调用
 * - 表达式 IR 生成
 * - 控制流 IR 生成
 * - RISC-V RV64GC 目标支持
 */

use crate::ast::*;
use crate::error::CodegenError;

/**
 * LLVM IR 类型映射
 */
fn type_to_llvm(ty: &Type) -> &'static str {
    match ty {
        Type::Int => "i32",
        Type::Long => "i64",
        Type::Float => "float",
        Type::Double => "double",
        Type::Bool => "i1",
        Type::String => "i8*",
        Type::Char => "i8",
        Type::Void => "void",
        Type::Optional(_) => "i64", // 简化: 使用 i64 包装
        Type::Array(_) => "i64*",
        Type::Custom(name) => {
            match name.as_str() {
                _ => "i64", // 默认使用 i64
            }
        }
    }
}

/**
 * 代码生成器
 */
pub struct CodeGenerator {
    ir_output: String,
    indent: usize,
    label_counter: usize,
    /// 变量名到 SSA 值的映射
    variables: std::collections::HashMap<String, String>,
}

impl CodeGenerator {
    pub fn new() -> Self {
        Self {
            ir_output: String::new(),
            indent: 0,
            label_counter: 0,
            variables: std::collections::HashMap::new(),
        }
    }

    fn emit(&mut self, line: &str) {
        let indent_str = "  ".repeat(self.indent);
        self.ir_output.push_str(&indent_str);
        self.ir_output.push_str(line);
        self.ir_output.push('\n');
    }

    fn emit_label(&mut self, label: &str) {
        self.ir_output.push_str(label);
        self.ir_output.push_str(":\n");
    }

    fn new_label(&mut self, prefix: &str) -> String {
        let label = format!("{}.{}", prefix, self.label_counter);
        self.label_counter += 1;
        label
    }

    /**
     * 生成模块
     */
    pub fn generate(&mut self, module: &Module) -> Result<String, CodegenError> {
        // 生成模块头
        self.emit("; CCAS 编译器生成的 LLVM IR");
        self.emit("; 目标: RISC-V RV64GC");
        self.emit("");
        self.emit("define i32 @main() {");
        self.indent += 1;

        // 生成每个函数的 IR
        for func in &module.functions {
            self.generate_function(func)?;
        }

        self.indent -= 1;
        self.emit("}");
        self.emit("");
        self.emit("ret i32 0");

        Ok(self.ir_output.clone())
    }

    /**
     * 生成函数
     */
    fn generate_function(&mut self, func: &Function) -> Result<(), CodegenError> {
        // 函数头
        let ret_type = type_to_llvm(&func.return_type);
        self.emit(&format!("; 函数: {}", func.name));

        // 函数体语句
        for stmt in &func.body.statements {
            self.generate_statement(stmt)?;
        }

        // 如果没有返回语句，添加默认返回
        self.emit("ret i32 0");

        Ok(())
    }

    /**
     * 生成语句
     */
    fn generate_statement(&mut self, stmt: &Stmt) -> Result<(), CodegenError> {
        match stmt {
            Stmt::Let(let_stmt) => {
                self.generate_let_statement(let_stmt)
            }
            Stmt::Return(return_stmt) => {
                self.generate_return_statement(return_stmt)
            }
            Stmt::Expr(expr_stmt) => {
                self.generate_expression(&expr_stmt.expr)?;
                Ok(())
            }
            Stmt::If(if_stmt) => {
                self.generate_if_statement(if_stmt)
            }
            Stmt::Loop(loop_stmt) => {
                self.generate_loop_statement(loop_stmt)
            }
            Stmt::Block(block_stmt) => {
                self.generate_block_statement(block_stmt)
            }
            Stmt::Assignment(assign_stmt) => {
                self.generate_assignment_statement(assign_stmt)
            }
            Stmt::Break(_) | Stmt::Continue(_) => {
                Ok(()) // TODO: 实现 break/continue
            }
        }
    }

    /**
     * 生成变量声明语句
     */
    fn generate_let_statement(&mut self, let_stmt: &LetStmt) -> Result<(), CodegenError> {
        let var_type = let_stmt.type_annotation
            .as_ref()
            .map(|t| type_to_llvm(t))
            .unwrap_or("i32");

        // 分配局部变量
        let alloca = self.new_label("alloca");
        self.emit(&format!("%{} = alloca {}", alloca, var_type));

        // 如果有初始化值
        if let Some(init) = &let_stmt.initializer {
            let value = self.generate_expression(init)?;
            self.emit(&format!("store {} %{}, {}* %{}", 
                var_type, value, var_type, alloca));
        }

        // 保存变量映射
        self.variables.insert(let_stmt.name.clone(), alloca);

        Ok(())
    }

    /**
     * 生成返回语句
     */
    fn generate_return_statement(&mut self, return_stmt: &ReturnStmt) -> Result<(), CodegenError> {
        if let Some(value) = &return_stmt.value {
            let result = self.generate_expression(value)?;
            let ret_type = type_to_llvm(&Type::Int); // 简化
            self.emit(&format!("ret {} %{}", ret_type, result));
        } else {
            self.emit("ret void");
        }
        Ok(())
    }

    /**
     * 生成 if 语句
     */
    fn generate_if_statement(&mut self, if_stmt: &IfStmt) -> Result<(), CodegenError> {
        // 生成条件
        if let Some(branch) = if_stmt.branches.first() {
            let cond_result = self.generate_expression(&branch.condition)?;

            // 创建标签
            let then_label = self.new_label("then");
            let else_label = self.new_label("else");
            let end_label = self.new_label("ifend");

            // 条件分支
            self.emit(&format!("br i1 %{}, label %{}, label %{}", 
                cond_result, then_label, else_label));

            // then 分支
            self.emit_label(&format!("{}:", then_label));
            self.generate_statement(&branch.body)?;

            // 跳转到结束
            self.emit(&format!("br label %{}", end_label));

            // else 分支
            self.emit_label(&format!("{}:", else_label));
            if let Some(else_body) = &if_stmt.else_branch {
                self.generate_statement(else_body)?;
            }

            // 结束标签
            self.emit_label(&format!("{}:", end_label));
        }

        Ok(())
    }

    /**
     * 生成循环语句
     * while 循环结构:
     *   loop_start:
     *     条件判断
     *     br cond, loop_body, loop_end
     *   loop_body:
     *     循环体
     *     br loop_start
     *   loop_end:
     */
    fn generate_loop_statement(&mut self, loop_stmt: &LoopStmt) -> Result<(), CodegenError> {
        let loop_start = self.new_label("loop");
        let loop_body = self.new_label("loopbody");
        let loop_end = self.new_label("loopend");

        // 跳到循环条件判断
        self.emit(&format!("br label %{}", loop_start));

        // 循环条件判断入口
        self.emit_label(&format!("{}:", loop_start));

        // 生成循环条件 (如果有)
        if let Some(cond) = &loop_stmt.condition {
            let cond_result = self.generate_expression(cond)?;
            // 条件为真跳到循环体，为假跳到循环结束
            self.emit(&format!("br i1 %{}, label %{}, label %{}", 
                cond_result, loop_body, loop_end));
        } else {
            // 无限循环，直接跳到循环体
            self.emit(&format!("br label %{}", loop_body));
        }

        // 循环体入口
        self.emit_label(&format!("{}:", loop_body));

        // 生成循环体
        self.generate_statement(&loop_stmt.body)?;

        // 循环体执行完后，跳回条件判断
        self.emit(&format!("br label %{}", loop_start));

        // 循环结束标签
        self.emit_label(&format!("{}:", loop_end));

        Ok(())
    }

    /**
     * 生成块语句
     */
    fn generate_block_statement(&mut self, block_stmt: &BlockStmt) -> Result<(), CodegenError> {
        for stmt in &block_stmt.statements {
            self.generate_statement(stmt)?;
        }
        Ok(())
    }

    /**
     * 生成赋值语句
     */
    fn generate_assignment_statement(&mut self, assign_stmt: &AssignmentStmt) -> Result<(), CodegenError> {
        // 生成值表达式
        let value = self.generate_expression(&assign_stmt.value)?;
        
        // 获取目标变量名并更新映射
        if let Expr::Identifier(ident) = &assign_stmt.target {
            if let Some(alloca) = self.variables.get(&ident.name).cloned() {
                // 存储到已有变量
                self.emit(&format!("store i32 %{}, i32* %{}", value, alloca));
            } else {
                // 新变量，分配空间
                let new_alloca = self.new_label("alloca");
                self.emit(&format!("%{} = alloca i32", new_alloca));
                self.emit(&format!("store i32 %{}, i32* %{}", value, new_alloca));
                self.variables.insert(ident.name.clone(), new_alloca);
            }
        } else {
            // 目标不是标识符，生成注释
            self.emit(&format!("; 赋值目标不是标识符"));
        }

        Ok(())
    }

    /**
     * 生成表达式
     */
    fn generate_expression(&mut self, expr: &Expr) -> Result<String, CodegenError> {
        match expr {
            Expr::Identifier(ident) => {
                // 查找变量的 SSA 值
                if let Some(alloca) = self.variables.get(&ident.name).cloned() {
                    let load = self.new_label("id");
                    self.emit(&format!("%{} = load i32, i32* %{}", load, alloca));
                    Ok(load)
                } else {
                    // 未找到变量，使用临时标签
                    Ok(self.new_label("id"))
                }
            }
            Expr::Literal(lit) => {
                self.generate_literal_expr(lit)
            }
            Expr::Binary(binary) => {
                self.generate_binary_expr(binary)
            }
            Expr::Unary(unary) => {
                self.generate_unary_expr(unary)
            }
            Expr::Call(call) => {
                self.generate_call_expr(call)
            }
            Expr::MemberAccess(_) => {
                Ok(self.new_label("member"))
            }
            Expr::Grouped(expr) => {
                self.generate_expression(expr)
            }
        }
    }

    /**
     * 生成字面量表达式
     */
    fn generate_literal_expr(&mut self, lit: &LiteralExpr) -> Result<String, CodegenError> {
        let result = self.new_label("lit");
        
        match &lit.kind {
            LiteralKind::Integer(n) => {
                self.emit(&format!("%{} = add i32 0, {}", result, n));
            }
            LiteralKind::Float(f) => {
                let bits = f.to_bits();
                self.emit(&format!("%{} = fadd float 0.0, 0x{:x}", result, bits));
            }
            LiteralKind::String(s) => {
                let escaped = s.replace("\\", "\\\\").replace("\"", "\\\"");
                self.emit(&format!("@.str.{} = private constant [{} x i8] c\"{}\\00\"", 
                    result, escaped.len() + 1, escaped));
                self.emit(&format!("%{} = getelementptr [{} x i8], [{} x i8]* @.str.{}, i32 0, i32 0", 
                    result, escaped.len() + 1, escaped.len() + 1, result));
            }
            LiteralKind::Char(c) => {
                let value = *c as i32;
                self.emit(&format!("%{} = add i8 0, {}", result, value));
            }
            LiteralKind::Boolean(b) => {
                let value = if *b { 1 } else { 0 };
                self.emit(&format!("%{} = add i1 0, {}", result, value));
            }
        }

        Ok(result)
    }

    /**
     * 生成字面量值
     */
    fn generate_literal_value(&self, expr: &Expr) -> Result<String, CodegenError> {
        if let Expr::Literal(lit) = expr {
            match &lit.kind {
                LiteralKind::Integer(n) => Ok(n.to_string()),
                LiteralKind::Boolean(b) => Ok(if *b { "1".to_string() } else { "0".to_string() }),
                _ => Ok("0".to_string()),
            }
        } else {
            Ok("0".to_string())
        }
    }

    /**
     * 生成二元表达式
     */
    fn generate_binary_expr(&mut self, binary: &BinaryExpr) -> Result<String, CodegenError> {
        let left = self.generate_expression(&binary.left)?;
        let right = self.generate_expression(&binary.right)?;
        let result = self.new_label("binop");

        let llvm_op = match binary.op {
            BinaryOp::Add => "add",
            BinaryOp::Sub => "sub",
            BinaryOp::Mul => "mul",
            BinaryOp::Div => "sdiv",
            BinaryOp::Rem => "srem",
            BinaryOp::And => "and",
            BinaryOp::Or => "or",
            BinaryOp::Eq => "icmp eq",
            BinaryOp::Ne => "icmp ne",
            BinaryOp::Gt => "icmp sgt",
            BinaryOp::Lt => "icmp slt",
            BinaryOp::Ge => "icmp sge",
            BinaryOp::Le => "icmp sle",
            BinaryOp::BitAnd => "and",
            BinaryOp::BitOr => "or",
            BinaryOp::BitXor => "xor",
            BinaryOp::Shl => "shl",
            BinaryOp::Shr => "lshr",
            BinaryOp::Assign => "add", // 特殊处理
        };

        // 处理赋值运算符
        if binary.op == BinaryOp::Assign {
            // 赋值表达式: target = value
            // 左侧应该是标识符
            if let Expr::Identifier(ident) = &*binary.left {
                if let Some(alloca) = self.variables.get(&ident.name).cloned() {
                    // 存储到已有变量
                    self.emit(&format!("store i32 %{}, i32* %{}", right, alloca));
                } else {
                    // 新变量，分配空间
                    let new_alloca = self.new_label("alloca");
                    self.emit(&format!("%{} = alloca i32", new_alloca));
                    self.emit(&format!("store i32 %{}, i32* %{}", right, new_alloca));
                    self.variables.insert(ident.name.clone(), new_alloca);
                }
            }
            // 返回右值作为结果
            return Ok(right);
        } else {
            self.emit(&format!("%{} = {} i32 %{}, %{}", result, llvm_op, left, right));
        }

        Ok(result)
    }

    /**
     * 生成一元表达式
     */
    fn generate_unary_expr(&mut self, unary: &UnaryExpr) -> Result<String, CodegenError> {
        let operand = self.generate_expression(&unary.operand)?;
        let result = self.new_label("unop");

        let llvm_op = match unary.op {
            UnaryOp::Neg => "sub",
            UnaryOp::Not => "xor",
            UnaryOp::BitNot => "xor",
        };

        match unary.op {
            UnaryOp::Neg => {
                self.emit(&format!("%{} = {} i32 0, %{}", result, llvm_op, operand));
            }
            UnaryOp::Not | UnaryOp::BitNot => {
                self.emit(&format!("%{} = {} i32 -1, %{}", result, llvm_op, operand));
            }
        }

        Ok(result)
    }

    /**
     * 生成函数调用表达式
     */
    fn generate_call_expr(&mut self, call: &CallExpr) -> Result<String, CodegenError> {
        // 获取函数名
        let func_name = match &*call.function {
            Expr::Identifier(ident) => ident.name.clone(),
            _ => "unknown".to_string(),
        };

        // 生成参数
        let mut args = Vec::new();
        
        // 检查是否是内置函数
        let is_builtin_print = func_name == "打印" || func_name == "print";
        
        for arg in &call.arguments {
            let arg_val = self.generate_expression(arg)?;
            if is_builtin_print {
                // 打印函数接受 i8* 字符串指针
                args.push(format!("i8* %{}", arg_val));
            } else {
                args.push(format!("i32 %{}", arg_val));
            }
        }

        let result = self.new_label("call");
        
        // 生成函数调用
        if args.is_empty() {
            if is_builtin_print {
                self.emit(&format!("%{} = call i32 @{}()", result, func_name));
            } else {
                self.emit(&format!("%{} = call i32 @{}()", result, func_name));
            }
        } else {
            let args_str = args.join(", ");
            if is_builtin_print {
                // 打印函数返回 i32
                self.emit(&format!("%{} = call i32 @{}({})", result, func_name, args_str));
            } else {
                self.emit(&format!("%{} = call i32 @{}({})", result, func_name, args_str));
            }
        }

        Ok(result)
    }
}

impl Default for CodeGenerator {
    fn default() -> Self {
        Self::new()
    }
}

/**
 * 代码生成入口函数
 */
pub fn generate_ir(module: &Module) -> Result<String, CodegenError> {
    let mut generator = CodeGenerator::new();
    generator.generate(module)
}
