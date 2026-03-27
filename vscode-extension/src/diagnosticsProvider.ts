/**
 * @file diagnosticsProvider.ts
 * @brief 错误诊断提供者
 * @description 提供实时语法检查和错误提示
 */

import * as vscode from 'vscode';
import * as cp from 'child_process';

/**
 * 玄语诊断提供者
 */
export class XuanYuDiagnosticsProvider implements vscode.Disposable {

    private diagnosticCollection: vscode.DiagnosticCollection;
    private debounceTimer: NodeJS.Timeout | undefined;

    constructor() {
        this.diagnosticCollection = vscode.languages.createDiagnosticCollection('xuanyu');
        
        // 监听文档变化
        vscode.workspace.onDidChangeTextDocument(this.onDocumentChange, this);
        
        // 监听文档打开
        vscode.workspace.onDidOpenTextDocument(this.onDocumentOpen, this);
        
        // 对当前打开的文档进行诊断
        if (vscode.window.activeTextEditor) {
            this.diagnose(vscode.window.activeTextEditor.document);
        }
    }

    /**
     * 文档变化时触发
     */
    private onDocumentChange(event: vscode.TextDocumentChangeEvent) {
        if (event.document.languageId === 'xuanyu') {
            this.debouncedDiagnose(event.document);
        }
    }

    /**
     * 文档打开时触发
     */
    private onDocumentOpen(document: vscode.TextDocument) {
        if (document.languageId === 'xuanyu') {
            this.diagnose(document);
        }
    }

    /**
     * 防抖诊断
     */
    private debouncedDiagnose(document: vscode.TextDocument) {
        if (this.debounceTimer) {
            clearTimeout(this.debounceTimer);
        }
        this.debounceTimer = setTimeout(() => {
            this.diagnose(document);
        }, 500);
    }

    /**
     * 执行诊断
     */
    private diagnose(document: vscode.TextDocument) {
        const config = vscode.workspace.getConfiguration('xuanyu');
        
        // 检查是否启用诊断
        if (!config.get<boolean>('enableDiagnostics', true)) {
            this.diagnosticCollection.delete(document.uri);
            return;
        }

        const diagnostics: vscode.Diagnostic[] = [];
        const text = document.getText();

        // 基本的语法检查
        this.checkBasicSyntax(text, document, diagnostics);
        
        // 检查括号匹配
        this.checkBrackets(text, document, diagnostics);
        
        // 检查关键字使用
        this.checkKeywords(text, document, diagnostics);

        this.diagnosticCollection.set(document.uri, diagnostics);
    }

    /**
     * 基本语法检查
     */
    private checkBasicSyntax(text: string, document: vscode.TextDocument, diagnostics: vscode.Diagnostic[]) {
        const lines = text.split('\n');
        
        lines.forEach((line, lineIndex) => {
            // 检查函数定义是否缺少返回类型
            const funcMatch = line.match(/函数\s+[^\s(]+\s*\([^)]*\)\s*(?!:)/);
            if (funcMatch && !line.includes('返回') && !line.includes('外部')) {
                const startPos = new vscode.Position(lineIndex, funcMatch.index!);
                const endPos = new vscode.Position(lineIndex, line.length);
                diagnostics.push(new vscode.Diagnostic(
                    new vscode.Range(startPos, endPos),
                    '函数定义可能缺少返回类型声明',
                    vscode.DiagnosticSeverity.Hint
                ));
            }
        });
    }

    /**
     * 括号匹配检查
     */
    private checkBrackets(text: string, document: vscode.TextDocument, diagnostics: vscode.Diagnostic[]) {
        const stack: { char: string; position: vscode.Position }[] = [];
        const pairs: { [key: string]: string } = { '(': ')', '[': ']', '{': '}' };
        const closing = [')', ']', '}'];

        let lineIndex = 0;
        let colIndex = 0;

        for (let i = 0; i < text.length; i++) {
            const char = text[i];
            
            if (char === '\n') {
                lineIndex++;
                colIndex = 0;
                continue;
            }

            if (pairs[char]) {
                stack.push({ char, position: new vscode.Position(lineIndex, colIndex) });
            } else if (closing.includes(char)) {
                if (stack.length === 0) {
                    diagnostics.push(new vscode.Diagnostic(
                        new vscode.Range(
                            new vscode.Position(lineIndex, colIndex),
                            new vscode.Position(lineIndex, colIndex + 1)
                        ),
                        `多余的 '${char}'`,
                        vscode.DiagnosticSeverity.Error
                    ));
                } else {
                    const last = stack.pop()!;
                    if (pairs[last.char] !== char) {
                        diagnostics.push(new vscode.Diagnostic(
                            new vscode.Range(
                                last.position,
                                new vscode.Position(lineIndex, colIndex)
                            ),
                            `括号不匹配: 期望 '${pairs[last.char]}' 但找到 '${char}'`,
                            vscode.DiagnosticSeverity.Error
                        ));
                    }
                }
            }
            colIndex++;
        }

        // 检查未闭合的括号
        for (const item of stack) {
            diagnostics.push(new vscode.Diagnostic(
                new vscode.Range(item.position, item.position),
                `未闭合的 '${item.char}'`,
                vscode.DiagnosticSeverity.Error
            ));
        }
    }

    /**
     * 关键字使用检查
     */
    private checkKeywords(text: string, document: vscode.TextDocument, diagnostics: vscode.Diagnostic[]) {
        const lines = text.split('\n');
        lines.forEach((line, lineIndex) => {
            // 检查 "若" 后是否缺少 "则"
            if (line.includes('若') && !line.includes('则') && !line.trim().startsWith('//')) {
                const ifMatch = line.match(/若\s+[^\s]+\s+(?!则)/);
                if (ifMatch) {
                    const startPos = new vscode.Position(lineIndex, ifMatch.index!);
                    const endPos = new vscode.Position(lineIndex, line.length);
                    diagnostics.push(new vscode.Diagnostic(
                        new vscode.Range(startPos, endPos),
                        '条件语句可能缺少 "则" 关键字',
                        vscode.DiagnosticSeverity.Hint
                    ));
                }
            }
        });
    }

    /**
     * 释放资源
     */
    dispose() {
        this.diagnosticCollection.dispose();
        if (this.debounceTimer) {
            clearTimeout(this.debounceTimer);
        }
    }
}
