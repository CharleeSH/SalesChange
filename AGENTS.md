# AGENTS.md Hermes自动化项目规范
## 分支规范
1. 所有新功能、修复必须新建分支：feature/xxx、fix/xxx
2. 禁止直接push代码到main主分支，修改完成提交PR合并
## Git提交规范
commit message 格式：feat/fix/docs/refactor: 简短描述
## 禁止操作
1. 禁止修改 .env、密钥、数据库相关配置文件
2. 禁止强制推送(force push)到主分支
3. 删除文件前必须确认用途，先提交Issue说明
## 构建测试
代码修改完成优先执行项目内置测试脚本
## 工作流
1. 读取仓库需求 → 创建分支 → 修改代码 → 本地验证 → 提交PR
2. PR合并前等待CI检查（如有）
