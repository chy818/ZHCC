/**
 * @file commands.ts
 * @brief 命令模块
 * @description 提供编译、运行等命令
 */

import * as vscode from 'vscode';
import * as cp from 'child_process';

/**
 * 玄语命令管理器
 */
export class XuanYuCommands {

    /**
     * 注册所有命令
     */
    static register(context: vscode.ExtensionContext) {
        // 编译命令
        context.subscriptions.push(
            vscode.commands.registerCommand('xuanyu.compile', () => {
                this.compile();
            })
        );

        // 运行命令
        context.subscriptions.push(
            vscode.commands.registerCommand('xuanyu.run', () => {
                this.run();
            })
        );

        // 显示 IR 命令
        context.subscriptions.push(
            vscode.commands.registerCommand('xuanyu.showIR', () => {
                this.showIR();
            })
        );
    }

    /**
     * 编译当前文件
     */
    private static async compile() {
        const editor = vscode.window.activeTextEditor;
        if (!editor) {
            vscode.window.showErrorMessage('没有打开的文件');
            return;
        }

        const document = editor.document;
        if (document.languageId !== 'xuanyu') {
            vscode.window.showErrorMessage('当前文件不是玄语文件');
            return;
        }

        // 先保存文件
        await document.save();

        const config = vscode.workspace.getConfiguration('xuanyu');
        const compilerPath = config.get<string>('compilerPath', 'xy');
        const filePath = document.fileName;

        vscode.window.withProgress({
            location: vscode.ProgressLocation.Notification,
            title: '正在编译...',
            cancellable: false
        }, async (progress) => {
            return new Promise<void>((resolve, reject) => {
                cp.exec(`"${compilerPath}" "${filePath}"`, (error, stdout, stderr) => {
                    if (error) {
                        vscode.window.showErrorMessage(`编译失败: ${stderr || error.message}`);
                        reject(error);
                    } else {
                        vscode.window.showInformationMessage('编译成功！');
                        resolve();
                    }
                });
            });
        });
    }

    /**
     * 运行当前文件
     */
    private static async run() {
        const editor = vscode.window.activeTextEditor;
        if (!editor) {
            vscode.window.showErrorMessage('没有打开的文件');
            return;
        }

        const document = editor.document;
        if (document.languageId !== 'xuanyu') {
            vscode.window.showErrorMessage('当前文件不是玄语文件');
            return;
        }

        const config = vscode.workspace.getConfiguration('xuanyu');
        const compilerPath = config.get<string>('compilerPath', 'xy');
        const filePath = document.fileName;

        // 先保存文件
        await document.save();

        // 创建终端并运行
        const terminal = vscode.window.createTerminal('玄语运行');
        terminal.show();
        terminal.sendText(`"${compilerPath}" "${filePath}" --run`);
    }

    /**
     * 显示 LLVM IR
     */
    private static async showIR() {
        const editor = vscode.window.activeTextEditor;
        if (!editor) {
            vscode.window.showErrorMessage('没有打开的文件');
            return;
        }

        const document = editor.document;
        if (document.languageId !== 'xuanyu') {
            vscode.window.showErrorMessage('当前文件不是玄语文件');
            return;
        }

        const config = vscode.workspace.getConfiguration('xuanyu');
        const compilerPath = config.get<string>('compilerPath', 'xy');
        const filePath = document.fileName;

        // 获取 IR
        cp.exec(`"${compilerPath}" "${filePath}" --ir`, (error, stdout, stderr) => {
            if (error) {
                vscode.window.showErrorMessage(`获取 IR 失败: ${stderr || error.message}`);
                return;
            }

            // 在新编辑器中显示 IR
            vscode.workspace.openTextDocument({
                content: stdout,
                language: 'llvm'
            }).then(doc => {
                vscode.window.showTextDocument(doc, {
                    preview: true,
                    viewColumn: vscode.ViewColumn.Beside
                });
            });
        });
    }
}
