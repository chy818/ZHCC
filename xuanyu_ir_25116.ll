; ==================== 内置函数 ====================

declare void @print(i8*)
declare i8* @rt_list_new()
declare void @rt_list_append(i8*, i8*)
declare i8* @rt_list_get(i8*, i64)
declare i64 @rt_list_len(i8*)
declare i64 @rt_string_len(i8*)
declare i64 @"输入整数"()
declare i8* @"输入文本"()
declare void @print_int(i64)
declare void @print_float(double)
declare void @print_bool(i1)
declare i64 @str_to_int(i8*)
declare i8* @int_to_str(i64)
declare i8* @create_list(i64)
declare i64 @list_add(i8*, i64)
declare i64 @list_get(i8*, i64)
declare i64 @list_len(i8*)
declare i8* @"文件读取"(i8*)
declare i32 @"文件写入"(i8*, i8*)
declare i32 @"文件存在"(i8*)
declare i32 @"文件删除"(i8*)
declare i32 @"执行命令"(i8*)
declare i8* @"命令输出"(i8*)
declare i64 @argc()
declare i8* @argv(i64)
declare i8* @str_concat(i8*, i8*)
declare i8* @str_slice(i8*, i64, i64)
declare i8* @str_contains(i8*, i8*)

; ==================== 用户函数 ====================

define i64 @compilerInit () {
; 函数: compilerInit
%alloca.0 = alloca i64
%id.1 = load i64, i64* %alloca.0
%id.2 = inttoptr i64 %id.1 to i8*
%member.3 = getelementptr i8, i8* %id.2, i32 0
%member_ptr.4 = bitcast i8* %member.3 to i64*
%member_val.5 = load i64, i64* %member_ptr.4
%id.7 = load i64, i64* %alloca.0
%id.8 = inttoptr i64 %id.7 to i8*
%member.9 = getelementptr i8, i8* %id.8, i32 0
%member_ptr.10 = bitcast i8* %member.9 to i64*
%member_val.11 = load i64, i64* %member_ptr.10
%lit.12 = add i64 0, 0
%id.14 = load i64, i64* %alloca.0
%id.15 = inttoptr i64 %id.14 to i8*
%member.16 = getelementptr i8, i8* %id.15, i32 0
%member_ptr.17 = bitcast i8* %member.16 to i64*
%member_val.18 = load i64, i64* %member_ptr.17
%lit.19 = add i64 0, 0
%id.21 = load i64, i64* %alloca.0
%id.22 = inttoptr i64 %id.21 to i8*
%member.23 = getelementptr i8, i8* %id.22, i32 0
%member_ptr.24 = bitcast i8* %member.23 to i64*
%member_val.25 = load i64, i64* %member_ptr.24
%lit.26 = add i64 0, 0
%id.28 = load i64, i64* %alloca.0
%id.29 = inttoptr i64 %id.28 to i8*
%member.30 = getelementptr i8, i8* %id.29, i32 0
%member_ptr.31 = bitcast i8* %member.30 to i64*
%member_val.32 = load i64, i64* %member_ptr.31
%lit.33 = add i64 0, 0
%id.35 = load i64, i64* %alloca.0
%id.36 = inttoptr i64 %id.35 to i8*
%member.37 = getelementptr i8, i8* %id.36, i32 0
%member_ptr.38 = bitcast i8* %member.37 to i64*
%member_val.39 = load i64, i64* %member_ptr.38
%lit.40 = add i64 0, 0
%id.42 = load i64, i64* %alloca.0
%id.43 = inttoptr i64 %id.42 to i8*
%member.44 = getelementptr i8, i8* %id.43, i32 0
%member_ptr.45 = bitcast i8* %member.44 to i64*
%member_val.46 = load i64, i64* %member_ptr.45
%lit.47 = add i64 0, 0
%id.49 = load i64, i64* %alloca.0
ret i64 %id.49
}
define void @compilerPrintBanner () {
; 函数: compilerPrintBanner
%lit.0 = getelementptr [40 x i8], [40 x i8]* @str_1, i32 0, i32 0
call void @print(i8* %lit.0)
%call.2 = add i64 0, 0
%lit.3 = getelementptr [37 x i8], [37 x i8]* @str_4, i32 0, i32 0
call void @print(i8* %lit.3)
%call.5 = add i64 0, 0
%lit.6 = getelementptr [37 x i8], [37 x i8]* @str_7, i32 0, i32 0
call void @print(i8* %lit.6)
%call.8 = add i64 0, 0
%lit.9 = getelementptr [40 x i8], [40 x i8]* @str_10, i32 0, i32 0
call void @print(i8* %lit.9)
%call.11 = add i64 0, 0
%lit.12 = getelementptr [0 x i8], [0 x i8]* @str_13, i32 0, i32 0
call void @print(i8* %lit.12)
%call.14 = add i64 0, 0
ret void
}
define void @compilerPrintHelp () {
; 函数: compilerPrintHelp
%lit.0 = getelementptr [31 x i8], [31 x i8]* @str_1, i32 0, i32 0
call void @print(i8* %lit.0)
%call.2 = add i64 0, 0
%lit.3 = getelementptr [0 x i8], [0 x i8]* @str_4, i32 0, i32 0
call void @print(i8* %lit.3)
%call.5 = add i64 0, 0
%lit.6 = getelementptr [7 x i8], [7 x i8]* @str_7, i32 0, i32 0
call void @print(i8* %lit.6)
%call.8 = add i64 0, 0
%lit.9 = getelementptr [29 x i8], [29 x i8]* @str_10, i32 0, i32 0
call void @print(i8* %lit.9)
%call.11 = add i64 0, 0
%lit.12 = getelementptr [33 x i8], [33 x i8]* @str_13, i32 0, i32 0
call void @print(i8* %lit.12)
%call.14 = add i64 0, 0
%lit.15 = getelementptr [27 x i8], [27 x i8]* @str_16, i32 0, i32 0
call void @print(i8* %lit.15)
%call.17 = add i64 0, 0
%lit.18 = getelementptr [0 x i8], [0 x i8]* @str_19, i32 0, i32 0
call void @print(i8* %lit.18)
%call.20 = add i64 0, 0
ret void
}
define i64 @main () {
; 函数: main
%alloca.0 = alloca i64
%id.1 = load i64, i64* %alloca.0
%call.2 = call i64 @compilerInit()
store i64 %call.2, i64* %alloca.0
%call.4 = call i64 @compilerPrintBanner()
%call.5 = call i64 @compilerPrintHelp()
%lit.6 = getelementptr [29 x i8], [29 x i8]* @str_7, i32 0, i32 0
call void @print(i8* %lit.6)
%call.8 = add i64 0, 0
%lit.9 = getelementptr [25 x i8], [25 x i8]* @str_10, i32 0, i32 0
call void @print(i8* %lit.9)
%call.11 = add i64 0, 0
%lit.12 = getelementptr [25 x i8], [25 x i8]* @str_13, i32 0, i32 0
call void @print(i8* %lit.12)
%call.14 = add i64 0, 0
%lit.15 = getelementptr [25 x i8], [25 x i8]* @str_16, i32 0, i32 0
call void @print(i8* %lit.15)
%call.17 = add i64 0, 0
%lit.18 = getelementptr [25 x i8], [25 x i8]* @str_19, i32 0, i32 0
call void @print(i8* %lit.18)
%call.20 = add i64 0, 0
%lit.21 = getelementptr [19 x i8], [19 x i8]* @str_22, i32 0, i32 0
call void @print(i8* %lit.21)
%call.23 = add i64 0, 0
%lit.24 = getelementptr [0 x i8], [0 x i8]* @str_25, i32 0, i32 0
call void @print(i8* %lit.24)
%call.26 = add i64 0, 0
%lit.27 = getelementptr [20 x i8], [20 x i8]* @str_28, i32 0, i32 0
call void @print(i8* %lit.27)
%call.29 = add i64 0, 0
%lit.30 = getelementptr [27 x i8], [27 x i8]* @str_31, i32 0, i32 0
call void @print(i8* %lit.30)
%call.32 = add i64 0, 0
%lit.33 = getelementptr [0 x i8], [0 x i8]* @str_34, i32 0, i32 0
call void @print(i8* %lit.33)
%call.35 = add i64 0, 0
%lit.36 = getelementptr [27 x i8], [27 x i8]* @str_37, i32 0, i32 0
call void @print(i8* %lit.36)
%call.38 = add i64 0, 0
%alloca.39 = alloca i64
%id.40 = load i64, i64* %alloca.39
%lit.41 = getelementptr [34 x i8], [34 x i8]* @str_42, i32 0, i32 0
%call.43 = call i64 @lexerRun(i8* %lit.41)
store i64 %call.43, i64* %alloca.39
%lit.45 = getelementptr [31 x i8], [31 x i8]* @str_46, i32 0, i32 0
call void @print(i8* %lit.45)
%call.47 = add i64 0, 0
%lit.48 = getelementptr [10 x i8], [10 x i8]* @str_49, i32 0, i32 0
call void @print(i8* %lit.48)
%call.50 = add i64 0, 0
%lit.51 = getelementptr [0 x i8], [0 x i8]* @str_52, i32 0, i32 0
call void @print(i8* %lit.51)
%call.53 = add i64 0, 0
%lit.54 = getelementptr [27 x i8], [27 x i8]* @str_55, i32 0, i32 0
call void @print(i8* %lit.54)
%call.56 = add i64 0, 0
%alloca.57 = alloca i64
%id.58 = load i64, i64* %alloca.57
%call.59 = call i64 @parserRun()
store i64 %call.59, i64* %alloca.57
%lit.61 = getelementptr [21 x i8], [21 x i8]* @str_62, i32 0, i32 0
call void @print(i8* %lit.61)
%call.63 = add i64 0, 0
%lit.64 = getelementptr [0 x i8], [0 x i8]* @str_65, i32 0, i32 0
call void @print(i8* %lit.64)
%call.66 = add i64 0, 0
%lit.67 = getelementptr [27 x i8], [27 x i8]* @str_68, i32 0, i32 0
call void @print(i8* %lit.67)
%call.69 = add i64 0, 0
%alloca.70 = alloca i64
%id.71 = load i64, i64* %alloca.70
%call.72 = call i64 @codegenRun()
store i64 %call.72, i64* %alloca.70
%lit.74 = getelementptr [21 x i8], [21 x i8]* @str_75, i32 0, i32 0
call void @print(i8* %lit.74)
%call.76 = add i64 0, 0
%lit.77 = getelementptr [0 x i8], [0 x i8]* @str_78, i32 0, i32 0
call void @print(i8* %lit.77)
%call.79 = add i64 0, 0
%lit.80 = getelementptr [29 x i8], [29 x i8]* @str_81, i32 0, i32 0
call void @print(i8* %lit.80)
%call.82 = add i64 0, 0
%lit.83 = getelementptr [25 x i8], [25 x i8]* @str_84, i32 0, i32 0
call void @print(i8* %lit.83)
%call.85 = add i64 0, 0
%lit.86 = getelementptr [49 x i8], [49 x i8]* @str_87, i32 0, i32 0
call void @print(i8* %lit.86)
%call.88 = add i64 0, 0
%lit.89 = add i64 0, 0
ret i64 %lit.89
}

; ==================== 字符串常量 ====================

@str_46 = private constant [31 x i8] c"   词法分析完成，识别 "
@str_68 = private constant [27 x i8] c"3. 测试代码生成器..."
@str_4 = private constant [0 x i8] c""
@str_78 = private constant [0 x i8] c""
@str_13 = private constant [25 x i8] c"  语法分析器: 就绪"
@str_49 = private constant [10 x i8] c" 个 Token"
@str_22 = private constant [19 x i8] c"  链接器: 就绪"
@str_84 = private constant [25 x i8] c"v0.2 Bootstrap 已就绪!"
@str_7 = private constant [29 x i8] c"=== 编译器模块状态 ==="
@str_34 = private constant [0 x i8] c""
@str_55 = private constant [27 x i8] c"2. 测试语法分析器..."
@str_87 = private constant [49 x i8] c"编译器可以用 XY 语言编写并编译自身"
@str_19 = private constant [25 x i8] c"  代码生成器: 就绪"
@str_16 = private constant [25 x i8] c"  语义分析器: 就绪"
@str_28 = private constant [20 x i8] c"=== 自展测试 ==="
@str_52 = private constant [0 x i8] c""
@str_62 = private constant [21 x i8] c"   语法分析完成"
@str_81 = private constant [29 x i8] c"=== 自展编译器完成 ==="
@str_1 = private constant [31 x i8] c"用法: xy <源文件> [选项]"
@str_42 = private constant [34 x i8] c"函数 main(): 整数 { 返回 0 }"
@str_65 = private constant [0 x i8] c""
@str_25 = private constant [0 x i8] c""
@str_75 = private constant [21 x i8] c"   代码生成完成"
@str_10 = private constant [25 x i8] c"  词法分析器: 就绪"
@str_31 = private constant [27 x i8] c"测试编译器各模块..."
@str_37 = private constant [27 x i8] c"1. 测试词法分析器..."
