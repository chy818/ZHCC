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
        Type::Struct(_) => "i64*", // 结构体指针
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
    /// 变量名到类型的映射
    variable_types: std::collections::HashMap<String, String>,
    /// 字符串常量表
    string_constants: std::collections::HashMap<String, String>,
}

impl CodeGenerator {
    pub fn new() -> Self {
        Self {
            ir_output: String::new(),
            indent: 0,
            label_counter: 0,
            variables: std::collections::HashMap::new(),
            variable_types: std::collections::HashMap::new(),
            string_constants: std::collections::HashMap::new(),
        }
    }

    /**
     * 计算结构体字段偏移
     * 简化处理：使用哈希表存储结构体字段信息
     */
    fn calculate_field_offset(&self, field_name: &str) -> i32 {
        // 常见的 Token 字段偏移（以 8 字节为单位）
        match field_name {
            "类型" | "type" => 0,
            "字面量" | "literal" => 8,
            "行" | "line" => 16,
            "列" | "column" => 24,
            _ => 0, // 默认偏移
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
        // 生成内置函数声明
        self.emit("; ==================== 内置函数 ====================");
        self.emit("");
        
        // 打印函数
        self.emit("declare i32 @打印(i8*)");
        self.emit("declare i32 @打印整数(i32)");
        self.emit("declare i32 @打印浮点(float)");
        self.emit("declare i32 @打印布尔(i1)");
        
        // 类型转换函数
        self.emit("declare i32 @文本转整数(i8*)");
        self.emit("declare i8* @整数转文本(i32)");
        
        // 列表函数
        self.emit("declare i8* @创建列表(i32)");
        self.emit("declare i32 @列表添加(i8*, i32)");
        self.emit("declare i32 @列表获取(i8*, i32)");
        self.emit("declare i32 @列表长度(i8*)");
        
        // 文件 I/O 函数
        self.emit("declare i8* @文件读取(i8*)");
        self.emit("declare i32 @文件写入(i8*, i8*)");
        
        // 字符串函数
        self.emit("declare i8* @文本长度(i8*)");
        self.emit("declare i8* @文本拼接(i8*, i8*)");
        self.emit("declare i8* @文本切片(i8*, i32, i32)");
        self.emit("declare i8* @文本包含(i8*, i8*)");
        
        // 命令行参数函数
        self.emit("declare i32 @参数个数()");
        self.emit("declare i8* @获取参数(i32)");
        
        self.emit("");
        self.emit("; ==================== 字符串常量 ====================");
        self.emit("");
        self.generate_string_constants();
        
        self.emit("");
        self.emit("; ==================== 用户函数 ====================");
        self.emit("");

        // 生成每个函数的 IR
        for func in &module.functions {
            self.generate_function(func)?;
        }

        Ok(self.ir_output.clone())
    }

    /**
     * 生成字符串常量
     */
    fn generate_string_constants(&mut self) {
        let constants: Vec<(String, String)> = self.string_constants
            .iter()
            .map(|(k, v)| (k.clone(), v.clone()))
            .collect();
        
        for (label, content) in constants {
            let len = content.len() + 1;
            self.emit(&format!("@{} = private constant [{} x i8] c\"{}\"",
                label, len, content));
        }
    }

    /**
     * 生成函数
     */
    fn generate_function(&mut self, func: &Function) -> Result<(), CodegenError> {
        // 函数头 - 生成函数签名
        let ret_type = type_to_llvm(&func.return_type);
        
        // 生成参数列表
        let mut param_strs = Vec::new();
        for param in &func.params {
            let param_type = type_to_llvm(&param.param_type);
            param_strs.push(format!("{} %{}", param_type, param.name));
        }
        let params_str = param_strs.join(", ");
        
        self.emit(&format!("define {} @{}({}) {{", ret_type, func.name, params_str));
        self.emit(&format!("; 函数: {}", func.name));
        
        // 为每个参数创建分配指令
        for param in &func.params {
            let param_type = type_to_llvm(&param.param_type);
            let alloca = self.new_label("param");
            self.emit(&format!("%{} = alloca {}", alloca, param_type));
            self.emit(&format!("store {} %{}, {}* %{}", param_type, param.name, param_type, alloca));
            self.variables.insert(param.name.clone(), alloca);
            self.variable_types.insert(param.name.clone(), param_type.to_string());
        }

        // 检查函数是否有显式返回语句
        let has_return = func.body.statements.iter().any(|stmt| {
            matches!(stmt, Stmt::Return(_))
        });

        // 函数体语句
        for stmt in &func.body.statements {
            self.generate_statement(stmt)?;
        }

        // 如果没有返回语句，添加默认返回
        if !has_return {
            if func.return_type == Type::Void {
                self.emit("ret void");
            } else {
                self.emit("ret i32 0");
            }
        }

        self.emit("}");
        self.emit("");

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
            Stmt::StructDef(_) => {
                Ok(()) // TODO: 实现结构体定义生成
            }
            Stmt::EnumDef(_) => {
                Ok(()) // TODO: 实现枚举定义生成
            }
            Stmt::TypeAlias(_) => {
                Ok(()) // TODO: 实现类型别名生成
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

        // 记录变量及其类型
        self.variables.insert(let_stmt.name.clone(), alloca);
        self.variable_types.insert(let_stmt.name.clone(), var_type.to_string());

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
                // 获取变量类型
                let var_type = self.variable_types.get(&ident.name)
                    .cloned()
                    .unwrap_or_else(|| "i32".to_string());
                // 存储到已有变量
                self.emit(&format!("store {} %{}, {}* %{}", var_type, value, var_type, alloca));
            } else {
                // 获取值类型（从表达式推断）
                let var_type = "i32".to_string(); // 默认类型
                // 新变量，分配空间
                let new_alloca = self.new_label("alloca");
                self.emit(&format!("%{} = alloca {}", new_alloca, var_type));
                self.emit(&format!("store {} %{}, {}* %{}", var_type, value, var_type, new_alloca));
                self.variables.insert(ident.name.clone(), new_alloca);
                self.variable_types.insert(ident.name.clone(), var_type);
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
                // 查找变量的 SSA 值和类型
                if let Some(alloca) = self.variables.get(&ident.name).cloned() {
                    let var_type = self.variable_types.get(&ident.name)
                        .cloned()
                        .unwrap_or_else(|| "i32".to_string());
                    let load = self.new_label("id");
                    self.emit(&format!("%{} = load {}, {}* %{}", load, var_type, var_type, alloca));
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
            Expr::MemberAccess(member) => {
                // 生成对象表达式
                let object_val = self.generate_expression(&member.object)?;
                
                // 获取字段名
                let field_name = &member.member;
                
                // 计算字段偏移（简化处理：假设字段按顺序排列，每个字段8字节）
                let field_offset = self.calculate_field_offset(field_name);
                
                // 生成 GEP 指令获取字段指针
                let result = self.new_label("member");
                self.emit(&format!("%{} = getelementptr i8, i8* %{}, i32 {}", 
                    result, object_val, field_offset));
                
                // 将指针转换为对应类型的指针
                let result_ptr = self.new_label("member_ptr");
                self.emit(&format!("%{} = bitcast i8* %{} to i32*", result_ptr, result));
                
                // 加载字段值
                let result_val = self.new_label("member_val");
                self.emit(&format!("%{} = load i32, i32* %{}", result_val, result_ptr));
                
                Ok(result_val)
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
                    // 获取变量类型
                    let var_type = self.variable_types.get(&ident.name)
                        .cloned()
                        .unwrap_or_else(|| "i32".to_string());
                    // 存储到已有变量
                    self.emit(&format!("store {} %{}, {}* %{}", var_type, right, var_type, alloca));
                } else {
                    // 新变量，分配空间
                    let var_type = "i32".to_string();
                    let new_alloca = self.new_label("alloca");
                    self.emit(&format!("%{} = alloca {}", new_alloca, var_type));
                    self.emit(&format!("store {} %{}, {}* %{}", var_type, right, var_type, new_alloca));
                    self.variables.insert(ident.name.clone(), new_alloca);
                    self.variable_types.insert(ident.name.clone(), var_type);
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

        // 检查是否是内置函数
        let is_builtin_print = func_name == "打印" || func_name == "print";
        let is_builtin_to_int = func_name == "文本转整数";
        let is_builtin_to_str = func_name == "整数转文本";
        
        // 检查是否是列表函数
        let is_list_create = func_name == "创建列表";
        let is_list_add = func_name == "列表添加";
        let is_list_get = func_name == "列表获取";
        let is_list_len = func_name == "列表长度";
        let is_list_func = is_list_create || is_list_add || is_list_get || is_list_len;
        
        // 检查是否是文件函数
        let is_file_read = func_name == "文件读取";
        let is_file_write = func_name == "文件写入";
        let is_file_func = is_file_read || is_file_write;
        
        // 检查是否是字符串函数
        let is_str_len = func_name == "文本长度";
        let is_str_concat = func_name == "文本拼接";
        let is_str_slice = func_name == "文本切片";
        let is_str_contains = func_name == "文本包含";
        let is_str_func = is_str_len || is_str_concat || is_str_slice || is_str_contains;
        
        // 检查是否是命令行参数函数
        let is_arg_count = func_name == "参数个数";
        let is_arg_get = func_name == "获取参数";
        let is_arg_func = is_arg_count || is_arg_get;
        
        // 生成参数
        let mut args = Vec::new();
        
        for (idx, arg) in call.arguments.iter().enumerate() {
            let arg_val = self.generate_expression(arg)?;
            if is_str_slice {
                // 文本切片需要 (i8*, i32, i32)
                // idx=0: 字符串 (i8*), idx=1: 起始位置 (i32), idx=2: 结束位置 (i32)
                if idx == 0 {
                    args.push(format!("i8* %{}", arg_val));
                } else {
                    args.push(format!("i32 %{}", arg_val));
                }
            } else if is_builtin_print || is_builtin_to_int || is_file_func || is_str_func {
                // 打印函数、文本转整数、文件函数、字符串函数接受 i8* 字符串指针
                args.push(format!("i8* %{}", arg_val));
            } else if is_builtin_to_str {
                // 整数转文本接受 i32
                args.push(format!("i32 %{}", arg_val));
            } else if is_list_func {
                // 列表函数接受 i8* 字符串指针
                args.push(format!("i8* %{}", arg_val));
            } else {
                args.push(format!("i32 %{}", arg_val));
            }
        }

        let result = self.new_label("call");
        
        // 生成函数调用
        if args.is_empty() {
            self.emit(&format!("%{} = call i32 @{}()", result, func_name));
        } else {
            let args_str = args.join(", ");
            
            if is_builtin_to_str || is_list_create || is_file_read || is_str_func || is_arg_get {
                // 整数转文本、创建列表、文件读取、字符串函数、获取参数返回 i8*
                self.emit(&format!("%{} = call i8* @{}({})", result, func_name, args_str));
            } else if is_file_write || is_arg_count {
                // 文件写入、参数个数返回 i32
                self.emit(&format!("%{} = call i32 @{}({})", result, func_name, args_str));
            } else {
                // 其他内置函数返回 i32
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
