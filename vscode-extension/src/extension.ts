/**
 * @file extension.ts
 * @brief 玄语 VS Code 插件入口
 * @description 提供语法高亮、代码补全、错误提示等功能
 */

import * as vscode from 'vscode';
import { XuanYuCompletionProvider } from './completionProvider';
import { XuanYuDiagnosticsProvider } from './diagnosticsProvider';
import { XuanYuCommands } from './commands';

/**
 * 插件激活时调用
 */
export function activate(context: vscode.ExtensionContext) {
    console.log('玄语插件已激活');

    // 注册代码补全提供者
    const completionProvider = vscode.languages.registerCompletionItemProvider(
        'xuanyu',
        new XuanYuCompletionProvider(),
        ' ', '.', ':', '(', '"', "'"
    );
    context.subscriptions.push(completionProvider);

    // 初始化诊断提供者
    const diagnosticsProvider = new XuanYuDiagnosticsProvider();
    context.subscriptions.push(diagnosticsProvider);

    // 注册命令
    XuanYuCommands.register(context);

    // 显示激活消息
    vscode.window.showInformationMessage('玄语插件已加载');
}

/**
 * 插件停用时调用
 */
export function deactivate() {
    console.log('玄语插件已停用');
}
