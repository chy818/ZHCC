/**
 * @file completionProvider.ts
 * @brief 代码补全提供者
 * @description 提供关键字、函数、变量等的代码补全
 */

import * as vscode from 'vscode';

/**
 * 玄语代码补全提供者
 */
export class XuanYuCompletionProvider implements vscode.CompletionItemProvider {

    /**
     * 中文关键字列表
     */
    private readonly chineseKeywords = [
        { label: '函数', detail: '定义函数', snippet: '函数 ${1:名称}(${2:参数}): ${3:返回类型} {\n\t$0\n}' },
        { label: '返回', detail: '返回语句', snippet: '返回 $0' },
        { label: '若', detail: '条件判断', snippet: '若 ${1:条件} 则 {\n\t$0\n}' },
        { label: '否则', detail: '否则分支', snippet: '否则 {\n\t$0\n}' },
        { label: '循环', detail: '无限循环', snippet: '循环 {\n\t$0\n}' },
        { label: '当', detail: '条件循环', snippet: '当 ${1:条件} {\n\t$0\n}' },
        { label: '定义', detail: '变量定义', snippet: '定义 ${1:变量名}: ${2:类型} = ${3:初始值}' },
        { label: '可变', detail: '可变变量', snippet: '可变 ${1:变量名}: ${2:类型} = ${3:初始值}' },
        { label: '常量', detail: '常量定义', snippet: '常量 ${1:名称}: ${2:类型} = ${3:值}' },
        { label: '导入', detail: '导入模块', snippet: '导入 "${1:模块路径}"' },
        { label: '导出', detail: '导出符号', snippet: '导出 ${1:符号名}' },
        { label: '结构体', detail: '结构体定义', snippet: '结构体 ${1:名称} {\n\t$0\n}' },
        { label: '枚举', detail: '枚举定义', snippet: '枚举 ${1:名称} {\n\t$0\n}' },
        { label: '类型', detail: '类型别名', snippet: '类型 ${1:名称} = ${2:类型}' },
        { label: '中断', detail: '跳出循环', snippet: '中断' },
        { label: '跳过', detail: '跳过本次循环', snippet: '跳过' },
        { label: '真', detail: '布尔真值', snippet: '真' },
        { label: '假', detail: '布尔假值', snippet: '假' },
        { label: '空', detail: '空值', snippet: '空' },
    ];

    /**
     * 英文关键字别名列表
     */
    private readonly englishKeywords = [
        { label: 'func', detail: '定义函数 (函数)', snippet: 'func ${1:name}(${2:params}): ${3:return_type} {\n\t$0\n}' },
        { label: 'return', detail: '返回语句 (返回)', snippet: 'return $0' },
        { label: 'if', detail: '条件判断 (若)', snippet: 'if ${1:condition} then {\n\t$0\n}' },
        { label: 'else', detail: '否则分支 (否则)', snippet: 'else {\n\t$0\n}' },
        { label: 'loop', detail: '无限循环 (循环)', snippet: 'loop {\n\t$0\n}' },
        { label: 'while', detail: '条件循环 (当)', snippet: 'while ${1:condition} {\n\t$0\n}' },
        { label: 'let', detail: '变量定义 (定义)', snippet: 'let ${1:name}: ${2:type} = ${3:value}' },
        { label: 'mut', detail: '可变变量 (可变)', snippet: 'mut ${1:name}: ${2:type} = ${3:value}' },
        { label: 'const', detail: '常量定义 (常量)', snippet: 'const ${1:name}: ${2:type} = ${3:value}' },
        { label: 'import', detail: '导入模块 (导入)', snippet: 'import "${1:module_path}"' },
        { label: 'export', detail: '导出符号 (导出)', snippet: 'export ${1:symbol}' },
        { label: 'struct', detail: '结构体定义 (结构体)', snippet: 'struct ${1:name} {\n\t$0\n}' },
        { label: 'enum', detail: '枚举定义 (枚举)', snippet: 'enum ${1:name} {\n\t$0\n}' },
        { label: 'break', detail: '跳出循环 (中断)', snippet: 'break' },
        { label: 'continue', detail: '跳过本次循环 (跳过)', snippet: 'continue' },
        { label: 'true', detail: '布尔真值 (真)', snippet: 'true' },
        { label: 'false', detail: '布尔假值 (假)', snippet: 'false' },
    ];

    /**
     * 内置类型列表
     */
    private readonly builtinTypes = [
        { label: '整数', detail: '整数类型 (Int)', documentation: '32位有符号整数' },
        { label: '浮点', detail: '浮点类型 (Float)', documentation: '单精度浮点数' },
        { label: '布尔', detail: '布尔类型 (Bool)', documentation: '布尔值 (真/假)' },
        { label: '文本', detail: '文本类型 (String)', documentation: 'UTF-8 编码字符串' },
        { label: '空类型', detail: '空类型 (Void)', documentation: '无返回值' },
        { label: 'Int', detail: '整数类型', documentation: '32位有符号整数' },
        { label: 'Float', detail: '浮点类型', documentation: '单精度浮点数' },
        { label: 'Bool', detail: '布尔类型', documentation: '布尔值 (true/false)' },
        { label: 'String', detail: '文本类型', documentation: 'UTF-8 编码字符串' },
        { label: 'Void', detail: '空类型', documentation: '无返回值' },
    ];

    /**
     * 常用函数列表
     */
    private readonly builtinFunctions = [
        { label: '打印整数', detail: '打印整数', snippet: '打印整数(${1:数值})' },
        { label: '打印浮点数', detail: '打印浮点数', snippet: '打印浮点数(${1:数值})' },
        { label: '打印文本', detail: '打印文本', snippet: '打印文本(${1:文本})' },
        { label: '打印换行', detail: '打印换行', snippet: '打印换行()' },
        { label: '读取整数', detail: '读取整数', snippet: '读取整数()' },
        { label: '读取文本行', detail: '读取文本行', snippet: '读取文本行()' },
        { label: '字符串长度', detail: '计算字符串长度', snippet: '字符串长度(${1:文本})' },
        { label: '数组长度', detail: '获取数组长度', snippet: '数组长度(${1:数组})' },
        { label: '绝对值', detail: '计算绝对值', snippet: '绝对值(${1:数值})' },
        { label: '平方根', detail: '计算平方根', snippet: '平方根(${1:数值})' },
    ];

    /**
     * 提供代码补全项
     */
    provideCompletionItems(
        document: vscode.TextDocument,
        position: vscode.Position,
        token: vscode.CancellationToken,
        context: vscode.CompletionContext
    ): vscode.ProviderResult<vscode.CompletionItem[] | vscode.CompletionList> {
        const items: vscode.CompletionItem[] = [];

        // 添加中文关键字
        for (const kw of this.chineseKeywords) {
            const item = new vscode.CompletionItem(kw.label, vscode.CompletionItemKind.Keyword);
            item.detail = kw.detail;
            item.insertText = new vscode.SnippetString(kw.snippet);
            items.push(item);
        }

        // 添加英文关键字别名
        for (const kw of this.englishKeywords) {
            const item = new vscode.CompletionItem(kw.label, vscode.CompletionItemKind.Keyword);
            item.detail = kw.detail;
            item.insertText = new vscode.SnippetString(kw.snippet);
            items.push(item);
        }

        // 添加内置类型
        for (const t of this.builtinTypes) {
            const item = new vscode.CompletionItem(t.label, vscode.CompletionItemKind.TypeParameter);
            item.detail = t.detail;
            item.documentation = new vscode.MarkdownString(t.documentation);
            items.push(item);
        }

        // 添加内置函数
        for (const fn of this.builtinFunctions) {
            const item = new vscode.CompletionItem(fn.label, vscode.CompletionItemKind.Function);
            item.detail = fn.detail;
            item.insertText = new vscode.SnippetString(fn.snippet);
            items.push(item);
        }

        // 从当前文档中提取函数名和变量名
        this.extractDocumentSymbols(document).forEach(symbol => {
            items.push(symbol);
        });

        return items;
    }

    /**
     * 从文档中提取符号
     */
    private extractDocumentSymbols(document: vscode.TextDocument): vscode.CompletionItem[] {
        const items: vscode.CompletionItem[] = [];
        const text = document.getText();
        
        // 匹配函数定义: 函数 名称(...):
        const funcRegex = /函数\s+([^\s(]+)\s*\(/g;
        let match;
        while ((match = funcRegex.exec(text)) !== null) {
            const item = new vscode.CompletionItem(match[1], vscode.CompletionItemKind.Function);
            item.detail = '当前文件中的函数';
            items.push(item);
        }

        // 匹配变量定义: 定义 名称:
        const varRegex = /定义\s+(?:可变\s+)?([^\s:]+)\s*:/g;
        while ((match = varRegex.exec(text)) !== null) {
            const item = new vscode.CompletionItem(match[1], vscode.CompletionItemKind.Variable);
            item.detail = '当前文件中的变量';
            items.push(item);
        }

        return items;
    }
}
