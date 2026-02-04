# TODO

moon fmt が直せず、moon check が対応できないベストプラクティスを中心にルールを拡充する。

- [ ] parser が `..<=` をネイティブ対応したら `parser_compat.mbt` の `normalize_range_lt_inclusive` を削除し、テストも更新する

## 実装計画

### Phase 0 (完了)
- ルール実装を `rules/` に分離し、`tasks/` を利用側インターフェースにする
- Diagnostic/Fix を追加し、`--fix` による自動修正を導入

### Phase 1 (AST のみで可能なルールを優先)
- 単純な構文変換で完結するルールを実装
- autofix は「安全に置換できるときだけ」付与

### Phase 1.5 (ベンチマークで可否判断)
- 関数型/パイプライン化で性能劣化があるかを先に測定
- 測定結果に基づいて「提案のみ」か「autofix」かを決める
- 中規模データで測定 (10^4〜10^5 要素目安)
- ターゲットは native / js / wasm を対象

### Phase 2 (構文だけでは不十分なルール)
- 追加の判定条件が必要なルールを実装
- 可能なら軽量な解析ヘルパーを追加

### Phase 3 (運用面の充実)
- ルールの ON/OFF、severity、カテゴリ分け
- Fix の競合解消・複数ファイル対応

## ルール一覧

### 実装済み
- [x] `match_try_question`  
  `match (try? expr)` を `try ... catch ... noraise` に誘導
- [x] `string_literal_multiply_number`  
  `"<literal>" * n` を `"<literal>".repeat(n)` に誘導  
  文字列/整数リテラルの場合は autofix

### Phase 1 (AST のみ)
- [x] `boolean_if_true_false`  
  `if cond { true } else { false }` → `cond` (fix)
- [x] `boolean_if_false_true`  
  `if cond { false } else { true }` → `!cond` (fix)
- [x] `redundant_if_same_branch`  
  `if cond { expr } else { expr }` → `expr` (fix)
- [x] `legacy_call_syntax`  
  旧構文 `f!(...)` / `f(...)?` を通常呼び出しに置換 (fix)
- [x] `c_style_for_simple_range`  
  `for i = 0; i < n; { ... continue i+1 }` → `for i in 0..<n` (fix)

### Phase 2 (条件付き・追加判定)
- [x] `match_option_unwrap_or`  
  `match opt { Some(v) => v; None => default }` → `opt.unwrap_or(default)` (fix)
- [x] `match_option_map`  
  `match opt { Some(v) => f(v); None => None }` → `opt.map(f)` (fix)
- [x] `match_option_do_nothing`  
  `match opt { Some(v) => { ... }; None => () }` → `if opt is Some(v) { ... }` (fix)
- [x] `match_result_try`  
  `match (try? expr)` の変種 (入れ子・複合条件) を包括的に検出
- [x] `if_let_to_match` / `match_to_if_let`  
  片側の分岐が `None` / `Some` だけの簡易パターン変換 (fix)

### LLM の手続き型コードを関数型イディオムへ
- [ ] `loop_collect_map`  
  `let mut out = [] ; for x in xs { out.push(f(x)) }` → `xs.map(f)` (fix)
- [ ] `loop_collect_filter`  
  `let mut out = [] ; for x in xs { if p(x) { out.push(x) } }` → `xs.filter(p)` (fix)
- [ ] `loop_collect_filter_map`  
  `let mut out = [] ; for x in xs { match f(x) { Some(v) => out.push(v); None => () } }` → `xs.filter_map(f)` (fix)
- [ ] `loop_sum_fold`  
  `let mut acc = 0 ; for x in xs { acc += f(x) }` → `xs.fold(init=0, ...)` (fix)
- [ ] `loop_string_builder_join`  
  `StringBuilder` + 逐次追加 → `xs.map(...).join(sep)` (条件付き / core は StringBuilder/Buffer 推奨なので要検証)
- [ ] `index_loop_for_each`  
  `for i = 0; i < xs.length(); { ... xs[i] ... }` → `for i, x in xs { ... }` (fix)

### LLM 手続き型補正の追加候補 (適用可否の検証対象)
- [x] `prefer_eta_reduce`  
  `fn(x){ f(x) }` / `x => f(x)` → `f` (fix)
- [x] `prefer_tuple_destructure`  
  `let a = t.0; let b = t.1` → `let (a, b) = t` (fix)
- [ ] `avoid_unused_binding`  
  使われない `let x = ...` を `_` に、または式へインライン化 (提案)
- [x] `prefer_expression_over_return`  
  `return expr` / `return ()` を末尾式へ寄せる提案 (提案)
- [ ] `prefer_match_over_if_chain`  
  enum/ADT らしい値への `if/else if` 連鎖を `match` へ (提案)
- [x] `avoid_side_effect_in_map`  
  `map` の戻り値を捨てる副作用コードを検出し、`iter().each` へ (提案)
- [ ] `prefer_option_filter` / `prefer_option_bind`  
  `match Option` の片側分岐を `filter`/`bind` へ (提案, `bind` は型依存/`match_option_map` と競合)
- [ ] `prefer_result_map_err` / `prefer_result_bind`  
  `match Result` の片側分岐を `map_err`/`bind` へ (提案, `bind` は型依存)
- [ ] `prefer_no_mut_global`  
  グローバル可変やクロージャ外部の `mut` 参照を検出して注意喚起 (提案)

### dotdot chain (..a()..b()) への書き換え
- [x] `dotdot_chain_sequence`  
  `obj.a(); obj.b(); obj.c()` → `obj..a()..b()..c()` (fix)
- [ ] `dotdot_chain_rebind`  
  `let obj = obj.a(); let obj = obj.b();` → `obj..a()..b()` (fix, 条件付き)

### パイプライン演算子 (|>) を使った書き換え
- [ ] `prefer_pipeline_nested_calls`  
  `f(g(h(x)))` → `x |> h |> g |> f` (fix)
- [x] `prefer_pipeline_rebind`  
  `let x = f(x); let y = g(x, ...)` の連鎖を検出して提案
- [ ] `prefer_pipeline_temp_var`  
  `let tmp = f(x); g(tmp)` → `x |> f |> g` (fix)
- [x] `prefer_pipeline`  
  `g(f(x))` / `h(g(f(x)))` の「単引数のみ」チェーンを検出して提案

### パターンマッチ/型イディオム
- [ ] `prefer_array_pattern`  
  `xs.get(0)` / `xs.length()==0` で分岐するコード → `match xs { [] | [head, ..] }` (提案)
- [ ] `prefer_string_pattern`  
  `s == ""` / `s.starts_with("...")` → `match s { "" | [.."prefix", ..rest] }` (提案)
- [ ] `avoid_double_option_param`  
  `arg? : T?` / `arg : T?` + optional 指定など二重 Option を検出して単一化を提案
- [ ] `avoid_unnecessary_mut`  
  `let mut x = ...` で再代入がない場合は `let x = ...` を提案

### 参照/ビュー型の推奨 (性能/表現)
- [ ] `prefer_readonly_array_param`  
  変更されない `Array[T]` 引数を `ReadOnlyArray[T]` へ誘導 (提案)
- [ ] `prefer_array_view_param`  
  変更されない `Array[T]`/`FixedArray[T]` 引数を `ArrayView[T]` へ誘導 (提案)
- [ ] `prefer_string_view_param`  
  変更されない `String` 引数を `StringView` へ誘導 (提案)
- [ ] `avoid_unnecessary_copy_slice`  
  `to_array()` / `to_string()` の不要コピーを `*View` へ置換 (提案)

### core ベストプラクティス由来 (要検証)
- [ ] `prefer_option_map_or_else`  
  `map_or(default, f)` の default が関数呼び出しなら `map_or_else` へ (lazy 評価)
- [ ] `prefer_option_unwrap_or_else`  
  `unwrap_or(default)` の default が関数呼び出しなら `unwrap_or_else` へ (lazy 評価)
- [ ] `prefer_string_builder_for_concat`  
  ループ内の `s = s + ...` / `s += ...` を `StringBuilder`/`Buffer` へ (perf)
- [ ] `avoid_string_from_array_large`  
  大きな `Array[Char]` → `String::from_array` を避け `StringBuilder`/`Buffer` を提案 (perf)
- [ ] `prefer_string_view_slice`  
  substring 生成は `text[:][start:end]` の `StringView` を優先し必要なら `to_string()` (perf)
- [ ] `prefer_unicode_safe_iteration`  
  `s[i]` / `s.get_char(i)` の手動走査を `for c in s` / `s.iter()` / パターンマッチへ (安全性)
- [ ] `prefer_map_get_pattern`  
  `map[key]` 直接アクセスを `get` + `match/guard` に誘導 (安全性)

### Async / Error handling
- [x] `async_cancellation_must_propagate`  
  async の `catch` で cancellation を握りつぶさない (`@async.is_being_cancelled()` を再 raise)
- [x] `prefer_task_group_spawn`  
  `@async.spawn` / `spawn_bg` を `@async.with_task_group` に寄せる
- [x] `spawn_result_must_be_used`  
  `group.spawn(...)` の戻り値 Task を未使用のまま捨てない
- [x] `spawn_bg_long_running_requires_no_wait`  
  `spawn_bg` で長寿命タスクは `no_wait=true` を要求
- [x] `no_wrap_generic_error`  
  `suberror WrapA(Error)` のような汎用 Error を包むだけの型を避ける
- [x] `avoid_abort_in_error_paths`  
  `catch` 内の `abort/panic` を抑制
- [x] `prefer_noraise_async`  
  error effect のない `async fn` に `noraise` を付与する提案

### Test (TDD / snapshot)
- [x] `avoid_trivial_assert`  
  `assert_true(true)` / `assert_false(true)` / `assert_eq(x, x)` のような無意味な検証を検知
- [x] `prefer_input_expected_assert`  
  `assert_eq(f(x), y)` を input/expected/actual 変数に分解する提案

### Module / API
- [x] `require_doc_pub_fn`  
  `pub fn` に doc comment を必須化
- [x] `require_doc_pub_enum`  
  `pub enum` に doc comment を必須化
- [x] `using_only_in_file`  
  `using` は指定ファイル（file.mbt）に限定

### ベンチマーク (Phase 1.5 の前提)
- [ ] `bench_loop_vs_map_filter`  
  ループと `map/filter/fold` の比較
- [ ] `bench_prefer_pipeline_vs_nested`  
  `f(g(h(x)))` と `x |> h |> g |> f` の比較
- [ ] `bench_dotdot_chain`  
  `obj.a(); obj.b()` と `obj..a()..b()` の比較
- [ ] `bench_view_vs_copy`  
  `String`/`Array` のコピー vs `*View` の比較
- [ ] `bench_js_bundle_cost`  
  Map/Set/Json/Double::to_string の JS バンドルサイズ差分を測定

### JS バンドルサイズ制約向けルール
- [x] `avoid_map_set_js`  
  JS ターゲットで Map/Set 使用を検出し、軽量な代替を提案 (提案のみ)
- [x] `avoid_json_js`  
  JS ターゲットで Json 使用を検出し、手書きシリアライズ等を提案 (提案のみ)
- [x] `avoid_double_to_string_js`  
  JS ターゲットで `Double::to_string` 使用を検出 (提案のみ)

### Phase 3 (運用・拡張)
- [ ] `rule_config`  
  ルールごとの有効/無効・severity・カテゴリ(perf/fp/size)を設定ファイルから読み込み
- [ ] `fix_conflict_resolution`  
  重複・交差する Fix の検知とスキップ理由の表示

## カテゴリ方針
- perf / fp / size / async / error / test / module のタグを付与
- fp（関数型）系はデフォルト無効、明示的に有効化する
- async / error はデフォルト無効
