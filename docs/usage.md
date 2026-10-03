# 使用说明

## 项目级使用

将仓库内容安装到业务项目后，在业务项目目录打开 Codex，即可使用项目级 `fullstack-review` 和项目级清单。

在 Windows 上，建议优先使用项目级 .codex 目录；安装完成后重新打开 Codex，使项目级 skill 和清单生效。

主 skill 会根据实际文件、依赖和用户请求选择专业 skill：

- Java 和 JVM 代码：`backend/java-review`
- Spring Boot 配置、接口、事务和消息：`backend/springboot-review`
- 数据库引擎、SQL、索引、事务、锁和迁移：`backend/database-review`
- MyBatis、JPA/Hibernate、JDBC、Mapper 和 Repository：`backend/data-access-review`
- 前端页面、组件、状态和浏览器交互：`frontend-review`
- 认证、授权、注入、敏感数据和依赖安全：`security-review`
- 测试计划、常规测试用例和测试代码：`test-generation`

## 示例请求

~~~text
请审查本次 Java、Spring Boot 和 MyBatis 改动，输出问题、证据、根因、影响、修复建议、常规测试用例和未覆盖风险。
~~~

主 skill 会按范围组合多个专业 skill，不默认读取无关领域的清单。

## 清单解析

清单解析顺序固定为：

~~~text
当前业务项目/.codex/checklists/
    ↓ 对应文件不存在时
~/.codex/checklists/fullstack-quality-kit/
~~~

项目级清单优先于全局命名空间清单。两处都不存在时，应报告缺失，不回退到其他项目目录。

## 输出要求

审查结果至少说明：

- 触发场景和实际证据。
- 根因、影响范围和修复方向。
- 正常、异常、边界、权限、重复执行、并发或回归测试覆盖。
- 本次修改范围、全项目范围、未覆盖项和已知风险。
