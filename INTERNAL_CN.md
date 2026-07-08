# z0 内部架构

本文面向需要修改 z0 内部实现的开发者。z0 是一个 MoonBit 实现的、计划兼容 Z3 的 SMT solver，目前覆盖的核心是 CDCL(T) 风格的量词自由 Bool + EUF 子集。

## 分层视图

当前求解路径可以按四层理解：

```text
shell / SMT-LIB runner
  -> parsers/smt2
  -> cmd_context
  -> frontend/assembly
  -> solver facade
  -> solver/preprocess
  -> solver/smt_adapter
  -> smt.Solver / SmtContext
  -> sat.SatSolverCore + egraph.EGraph + theory plugins
```

每一层只暴露相邻层需要的接口：

- `shell` 只处理 CLI 参数、输入文件和输出归一化。
- `parsers/smt2` 把文本解析为 `SExpr`，再结合 `AstManager` 构造 `Command` 或 `ExprId`。
- `cmd_context` 执行命令，管理声明、选项、scope、取消和 resource limit。
- `frontend/assembly` 选择默认 `SolverFactory`。
- `solver` 是稳定门面，隐藏具体 backend。
- `solver/preprocess` 是可插拔包装层，当前只做 Bool rewrite。
- `solver/smt_adapter` 把门面请求转为 `smt.Solver` 请求，并处理 tracked assertion 和 unsat core 映射。
- `smt` 是 CDCL(T) glue 层，负责 SAT 内部化、EGraph/EUF、一组 theory plugin、模型和证明。

## 入口和命令执行

SMT-LIB 批处理入口从 `src/shell/main.mbt` 到 `src/parsers/smt2/runner.mbt`。runner 创建 `CommandContext`，逐个解析和执行命令。关键对象是 `CommandContext`：

- `manager : @ast.AstManager` 持有 sort、decl、expr、macro 和 AST scope。
- `factory : @solver.SolverFactory` 用于创建当前 solver。
- `solver : @solver.Solver` 是抽象 solver 门面。
- `options : Options` 保存 SMT-LIB options，例如 `:produce-models`、`:produce-proofs`、`:global-decls`。
- `resource_limit` 和 `cancel_flag` 在每条命令执行前 checkpoint。
- `output_lines` 和 `stderr_lines` 根据 regular/diagnostic channel 分流。

命令语义集中在 `CommandContext::execute_checked`：

- `set-logic` 目前接受 `QF_UF` 和 `ALL`。`QF_BOOL` 和其他逻辑会报 unsupported。
- `declare-sort`、`declare-const`、`declare-fun` 直接进入 `AstManager`。
- `define-fun` 当前只支持 nullary Bool macro。
- `assert` 先 macro expand，再 `rewrite_bool`，最后进入 `solver.assert_expr`。
- `assert` with `:named` 会创建一个 Bool tracker declaration，并调用 `solver.assert_expr_tracked`。
- `push/pop` 同步维护 solver scope 和 AST scope。当 `:global-decls` 为 false 时，声明也随 scope 回滚。
- `reset-assertions` 保留 manager、logic 和 options，但用同一 factory 重建 solver。
- `reset` 重建 manager 和 solver，并清空 logic。
- `check-sat` 和 `check-sat-assuming` 只返回结果文本。模型、proof、unsat core 等由后续查询命令读取当前结果缓存。

## AST 和 ID 模型

`src/ast` 是所有前端和 solver 层共享的 term store。它使用轻量 ID 引用 AST 节点：

- `@util.SortId`
- `@util.FuncDeclId`
- `@util.ExprId`
- `@ast.FamilyId`

`AstManager` 是这些 ID 的唯一解释者。外部包通常不直接构造 AST 结构，而是通过 `AstManager::mk_*`、`declare_*`、`lookup_*` 等方法。这样可以集中做 sort checking、family 标记、pretty printing 和 scoped rollback。

当前内建 family 包括 Bool、UF 和 Int/arithmetic 的基础标识。`FamilyDescriptor` 用来记录某个 family 是否已被当前实现支持，以及对应的 hook manifest。Theory 插件依赖 `FamilyId` 来声明自己拥有哪些 term。

Macro 由 `MacroManager` 和 `DefinedNames` 维护，`ast/rewriter` 负责展开和 Bool rewrite。命令层和 preprocess 层都会使用重写器，因此修改重写语义时要同时考虑：

- 直接 SMT-LIB assertion 的行为。
- 通过 `solver/preprocess` 包装后的 backend assertion。
- assumption/core 映射是否还能回到原始表达式。

## Solver 门面和 Backend

`src/solver` 的 `Solver` 是前端看见的统一 solver API。它不实现 CDCL(T)，而是保存状态并委托给 `SolverBackend`：

- assertion stack 和 tracked assertion stack 使用 `@util.ScopedVector`。
- `SolverFactoryConfig` 保存 logic、模型/证明/core 开关和 params。
- `current_result` 与 `stale_result` 控制模型、proof、unsat core 查询是否可用。
- `last_unsat_core` 和 `last_unsat_assumptions` 保存最近一次 unsat 的映射结果。

`SolverBackend` 是一组闭包：`assert_expr`、`assert_expr_tracked`、`push`、`pop`、`check_sat_assuming`、`model`、`proof`、`collect_statistics`、`translate`。这使得 preprocess、SMT adapter、未来的 tactic adapter 或其他 backend 都能以同一门面接入。

`check_sat` 的实现本质上是一次带 tracked assumptions 的 `check_sat_assuming`。`check_sat_assuming` 会把调用方 assumptions 和 tracked assertions 合并后传给 backend，再把 backend 返回的 assumption/core 映射回用户可见的 `UnsatAssumptionSet` 和 `UnsatCore`。

`produce_models` 可以在 assertion 后更新；`produce_proofs`、`produce_unsat_cores`、`produce_unsat_assumptions` 是 pre-assertion 选项，已有 assertion 后修改会返回 `late-option:*`。

## 默认 Solver 组装

默认入口是 `src/frontend/assembly/assembly.mbt`：

```text
frontend/assembly.solver_factory()
  -> solver/default_factory.default_factory()
  -> solver/preprocess.SolverPreprocess
  -> solver/smt_adapter.factory_with_theory_factories(...)
```

`solver/default_factory` 注册的额外 theory factory 包括：

- `arith_lite`，id 为 `th#2`，family 为当前 manager 的 arithmetic family。
- `fake_combo`，id 为 `th#3`，family 为 `FamilyId(70)`，主要用于组合和生命周期测试。

`solver/smt_adapter` 自己总会注册 EUF factory：

- `euf`，id 为 `th#1`，family 为当前 manager 的 UF family。

因此默认 concrete SMT solver 的 theory registry 是 `euf + arith_lite + fake_combo`，但实际可用能力仍由 assertion routing 和各插件实现决定。当前 README 中声明的主要可用片段仍是 Bool + EUF。

## SMT Context 和 CDCL(T) Glue

`src/smt/context.mbt` 的 `SmtContext` 是当前核心。它聚合：

- `sat_core : @sat.SatSolverCore`
- `egraph : @egraph.EGraph`
- `internalizer : SmtInternalizer`
- `assertions : ScopedVector[ExprId]`
- `unsupported_terms : ScopedVector[TheoryUnsupportedTerm]`
- `egraph_dispatch : EGraphDispatchState`
- `justifications : SmtJustificationStore`
- SAT extension 相关的 assumption、justification、propagation、conflict 队列
- `theories : Array[TheoryPlugin]`
- `qhead`，指向尚未内部化的 assertion
- `last_model`、`last_result` 和 proof assumption scope 缓存

`SmtContext::new` 创建 SAT core 和 EGraph，然后把 `context.sat_extension()` 安装到 SAT core。SAT core 通过这个 extension 回调向 SMT 层请求 theory propagation、theory conflict、antecedent materialization 和 justification 描述。

### Assertion 内部化

`SmtContext::assert_expr` 只把 assertion 放入 scoped vector，并标记缓存 stale。真正内部化发生在 `assert_new_roots`：

1. 从 `qhead` 开始遍历新增 assertions。
2. `smt_euf_assertion_route` 判断 assertion 是 Bool、EUF，还是 unsupported。
3. Bool assertion 通过 `SmtInternalizer::internalize_bool` 转成 SAT literal 和 defining clauses。
4. EUF assertion 转成 EGraph 新 eq/diseq fact。
5. unsupported term 记录到 `unsupported_terms`，之后 `check_sat` 会返回 unknown。

`SmtInternalizer` 负责 `ExprId <-> BoolVar/Literal` 绑定和 Tseitin 风格 Bool encoding。它只支持当前 AST 中的 Bool connective、Bool equality、nullary Bool app 等。非 Bool equality 和算术比较不由 Bool internalizer 处理。

### EUF 和 EGraph

`src/egraph` 提供 enode store、parent links、scope、theory attachments 和一个局部 `EGraphCongruence`。SMT 层目前使用两种 EUF 路径：

- assertion routing 把 EUF equalities/disequalities enqueue 到 `EGraph`。
- `smt_euf_check_assertions` 使用临时 `EGraphEufSearch` 和 congruence closure 判断当前 EUF assertions 是否自相矛盾。

当 EGraph 产生新 eq/diseq 时，`EGraphDispatchState::drain_new_facts` 会根据 enode 上的 theory var attachments，把 `EqFact` 或 `DiseqFact` 分发给拥有同一 `TheoryId` 的 plugin。

### Theory 生命周期

`theory/core` 把 theory 写成对象化 plugin。一个 plugin 由 descriptor 和一组可替换 hook 组成。`TheoryActions` 是 plugin 反向调用 SMT/SAT 的唯一通道，能做的事包括：

- internalize Bool expression。
- 添加 asserted clause 或 redundant lemma。
- 添加带 proof hint 的 lemma。
- 添加 extension assumption，用于 core 映射。
- enqueue theory propagation。
- 上报 conflict。
- mark unknown。
- materialize antecedent。
- 创建 proof hint。
- 访问 params、SAT assignment、scope depth 等上下文信息。

`SmtContext::run_theory_lifecycle` 的顺序是：

1. 对每个 theory 调用 `init_search`。
2. drain EGraph 新 fact。
3. 对可传播 theory 调用 `propagate`。
4. 重复调用 `theory_check`，直到没有插件返回 `TheoryCheckContinue`，或超过进度上限。
5. 调用 `finalize_check`。
6. 调用 `on_check_done`。

模型阶段另有 `init_model -> finalize_model -> model_incomplete_reason/validate_model`。Unsat 结果会调用各 theory 的 `validate_unsat_core`。

### check-sat 主流程

普通 `SmtContext::check_sat` 的顺序是：

1. 清理 extension action。
2. 内部化新增 assertions。
3. 如果有 unsupported term，返回 unknown。
4. 独立做 EUF consistency check。若冲突，materialize EUF proof hint，验证 unsat core 后返回 unsat。
5. 运行 theory lifecycle。若任何 theory give up，返回 unknown。
6. 调用 `sat_core.check()`。
7. 若 SAT，构造模型并运行 model lifecycle。模型构造或验证失败则返回 unknown，否则返回 sat。
8. 若 UNSAT，验证 unsat core 后返回 unsat。
9. 若 SAT core 返回 unknown，向上传递 unknown。

`check_sat_assuming` 在上述基础上多了一个临时 assumption scope：

- Bool assumptions 被 internalize 成 SAT assumptions。
- EUF assumptions 先由 `euf_assumption_core` 尝试最小化为 EUF core。
- extension assumptions 参与 SAT assumption core，并映射成 `SmtUnsatCoreEntry`。
- 结束后弹出临时 assumption scope。

## SAT Core

`src/sat` 是一个独立 SAT 层。核心类型包括：

- `BoolVar`、`Literal`、`Clause`、`ClauseId`。
- `ClauseDb`，区分 root clause、learned clause、deleted clause，并记录 event log。
- `SatSolverCore`，创建变量、添加 clause、执行 check、处理 assumptions、调用 extension。
- `SatExtension`，把 theory propagation、external assumptions、antecedent、validation 等 hook 暴露给 SMT 层。

SAT 层不知道 AST、sort 或 theory term。它只处理 literal 和 clause。所有高层含义都由 `SmtInternalizer`、`SmtContext` 和 `TheoryActions` 在边界处翻译。

## Model、Proof 和 Statistics

模型在 `src/model` 中表示。`SmtInternalizer::build_model` 先记录 Bool 常量解释，再让 `SmtModelBuilder` 根据 EGraph 和 theory plugins 构造 EUF value、universe value 和 function interpretation。Theory 可以通过 `mk_value`、`model_add_value`、`model_add_dep`、`include_func_interp` 等 hook 参与模型。

Proof 当前是轻量骨架，而不是完整 Z3 proof term：

- SAT clause event log 和 theory proof hints 组成 `ProofObject`。
- EUF conflict 会生成 `congruence` 或 `congruence(...)` hint。
- `ProofObjectChecker` 只验证当前上下文支持的 hint 形状和 owner。
- `solver/smt_adapter` 会为 tracked EUF assertion 重写 proof owner，使 named assertions 能出现在用户可见 proof/core 中。

Statistics 由 `src/stats` 提供 manifest、counter 和 merge policy。`solver`、`sat`、`arith_lite`、`fake_combo` 等包各自记录或汇总统计。`get-info :all-statistics` 通过 `CommandContext` 读取 `Solver::collect_statistics` 的 snapshot。

## Scope 和缓存不变量

scope 是该项目最重要的不变量之一：

- `CommandContext::push_scopes` 先 push solver，再在非 global declarations 模式下 push AST manager。
- `CommandContext::pop_scopes` 先 pop solver，再 pop AST manager。
- `Solver` 用 scoped vectors 保存 assertions 和 tracked assertions。
- `SmtContext::push` 会 push assertions、unsupported terms、EGraph、EGraph dispatch、justification store、extension assumptions、internalizer、SAT core 和每个 theory。
- `SmtContext::pop` 必须同步回滚上述结构，并把 `qhead` 截断到当前 assertion 长度以内。
- assumption check 使用额外临时 scope，只回滚 internalizer、EGraph、EGraph dispatch 和 SAT core。

所有会改变 assertions、scope、options 或 theory state 的操作都应标记当前结果 stale。模型、proof、unsat core 查询必须基于最近一次未 stale 的 check-sat 结果。

## 扩展入口

常见改动应优先落在以下位置：

- 新 SMT-LIB 命令或语法：`src/parsers/smt2` 增加解析，再在 `src/cmd_context` 执行。
- 新 AST 节点或 sort：`src/ast` 增加表示、构造、sort checking 和 pretty printing，必要时更新 `ast/rewriter`。
- 新 Bool 重写：`src/ast/rewriter`，并检查 `solver/preprocess` 的 assumption/core 映射。
- 新 solver backend：实现 `@solver.SolverBackend`，再通过 `SolverFactory` 暴露。
- 新 preprocess wrapper：按 `src/solver/preprocess` 的模式包装 base factory。
- 新 theory：在 `src/theory/<name>` 实现 `TheoryPlugin` 和 `TheoryFactory`，在 `solver/smt_adapter` 或 `solver/default_factory` 注册，并补齐 assertion routing、internalization、model/proof/core 验证。
- 新 theory term 和 EGraph 交互：使用 `SmtContext::attach_theory_var` 和 `EGraphDispatchState` 的 fact 分发约定。
- 新模型行为：扩展 `src/model` 或 `src/smt/model_builder.mbt`，并通过 theory model hooks 接入。
- 新 proof hint：扩展 `src/proof` 和 `SmtContext::proof_hint_checkers`，同时保证 SAT theory clause 有 hint，避免 proof checker 判为 invalid proof。

## 测试和接口信号

MoonBit 包以目录为编译单元，`moon.pkg` 定义依赖，`pkg.generated.mbti` 是 `moon info` 生成的公开接口摘要。做架构相关修改时建议遵守以下顺序：

1. 先看相关包的 `pkg.generated.mbti`，确认需要使用或改变的公开 API。
2. 对行为变化添加黑盒 `_test.mbt`；只有需要访问私有状态时使用 `_wbtest.mbt`。
3. 优先用 `inspect` snapshot 测试输出、event log、model/proof/core 文本。
4. 修改实现后运行 `moon info && moon fmt`。
5. 运行相关包测试，必要时再跑 `moon test`。
6. 检查 `.mbti` diff。若只是内部重构，`.mbti` 通常不应变化。

当前已有测试覆盖了 parser、cmd context、SAT core、SMT context、EGraph、theory lifecycle、model、proof、preprocess、default factory、shell 等关键路径。新增功能应尽量放在对应包内做局部测试，再用 `parsers/smt2` 或 `shell` 测一条端到端 SMT-LIB 流程。
