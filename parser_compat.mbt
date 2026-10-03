///|
fn normalize_range_lt_inclusive(source : String) -> String {
  // TODO: parser が `..<=` を対応したら、この正規化を削除する。
  let view = source[:]
  match view.find("..<=") {
    None => return source
    Some(_) => ()
  }
  let lex_result = @lexer.tokens_from_string_with_utf16_location(
    source[:],
    comment=true,
  )
  if lex_result.errors.length() > 0 {
    return source
  }
  let sb = StringBuilder::new()
  let mut last = 0
  let mut changed = false
  for _, triple in lex_result.tokens {
    let (tok, start, end) = triple
    if tok is @tokens.Token::RANGE_LT_INCLUSIVE {
      let start_idx = start.cnum
      let end_idx = end.cnum
      if start_idx < last || end_idx < start_idx {
        return source
      }
      let prefix = source[last:start_idx]
      changed = true
      sb..write_view(prefix).write_string("..= ")
      last = end_idx
    }
  }
  if !changed {
    return source
  }
  let suffix = source[last:]
  sb.write_view(suffix)
  sb.to_string()
}

///|
fn is_parser_trivia_token(tok : @tokens.Token) -> Bool {
  tok is @tokens.Token::NEWLINE || tok is @tokens.Token::COMMENT(_)
}

///|
fn prev_significant_token(
  tokens : @tokens.Triples,
  index : Int,
) -> @tokens.Token? {
  let mut i = index - 1
  while i >= 0 {
    let (tok, _, _) = tokens[i]
    if !is_parser_trivia_token(tok) {
      return Some(tok)
    }
    i -= 1
  }
  None
}

///|
fn next_significant_token(
  tokens : @tokens.Triples,
  index : Int,
) -> @tokens.Token? {
  let mut i = index + 1
  while i < tokens.length() {
    let (tok, _, _) = tokens[i]
    if !is_parser_trivia_token(tok) {
      return Some(tok)
    }
    i += 1
  }
  None
}

///|
// Keep legacy syntax parseable for migration rules without changing offsets.
// Token-based edits leave comments and string literals untouched.
fn normalize_legacy_syntax(source : String) -> String {
  let lexed = @lexer.tokens_from_string_with_utf16_location(
    source[:],
    comment=true,
  )
  if !lexed.errors.is_empty() {
    return source
  }
  let sb = StringBuilder::new()
  let mut last = 0
  for i in 0..<lexed.tokens.length() {
    let (token, start, end) = lexed.tokens[i]
    match token {
      @tokens.Token::INTERP(parts)
      | @tokens.Token::MULTILINE_INTERP(parts)
      | @tokens.Token::BYTES_INTERP(parts)
      | @tokens.Token::REGEX_INTERP(parts) =>
        for part in parts {
          if part is @tokens.InterpElem::InterpSource({ loc, .. }) {
            sb.write_view(source[last:loc.start.cnum])
            sb.write_string(
              normalize_legacy_syntax(
                source[loc.start.cnum:loc.end.cnum].to_owned(),
              ),
            )
            last = loc.end.cnum
          }
        }
      _ => ()
    }
    let replacement = match token {
      @tokens.Token::TRY_QUESTION => Some("try!")
      @tokens.Token::EXCLAMATION | @tokens.Token::QUESTION => {
        let previous = prev_significant_token(lexed.tokens, i)
        let next = next_significant_token(lexed.tokens, i)
        match (previous, next) {
          (
            Some(
              @tokens.Token::LIDENT(_)
              | @tokens.Token::UIDENT(_)
              | @tokens.Token::RPAREN
              | @tokens.Token::RBRACKET
            ),
            Some(@tokens.Token::LPAREN),
          ) => Some(" ")
          (Some(@tokens.Token::RPAREN), _) if token is @tokens.Token::QUESTION =>
            Some(" ")
          _ => None
        }
      }
      _ => None
    }
    if replacement is Some(text) {
      sb.write_view(source[last:start.cnum])
      sb.write_string(text)
      last = end.cnum
    }
  }
  sb.write_view(source[last:])
  sb.to_string()
}

///|
fn attach_docstrings_for_lint(
  docstrings : Array[@list.List[(@basic.Location, @tokens.Comment)]],
  toplevels : @syntax.Impls,
) -> Unit {
  fn skip_docstrings_before(
    pos : @basic.Position,
  ) -> @list.List[(@basic.Location, @tokens.Comment)]? {
    let mut previous = None
    while docstrings.last() is Some(comments) &&
          comments.last().unwrap().0.end <= pos {
      previous = docstrings.pop()
    }
    previous
  }

  fn make_doc(
    comments : @list.List[(@basic.Location, @tokens.Comment)],
  ) -> @syntax.DocString {
    {
      content: comments.map(p => {
        match p.1.content {
          [.. "///|", .. remain] | [.. "///", .. remain] => remain.to_string()
          _ => panic()
        }
      }),
      loc: {
        start: comments.head().unwrap().0.start,
        end: comments.last().unwrap().0.end,
      },
    }
  }

  for toplevel in toplevels {
    let previous = skip_docstrings_before(toplevel.loc().start)
    let doc = previous.map(make_doc).unwrap_or(@syntax.DocString::empty())
    match toplevel {
      @syntax.Impl::TopTypeDef(td) => {
        td.doc = doc
        match td.components {
          @syntax.TypeDesc::Abstract
          | @syntax.TypeDesc::ExtensibleEnum(None)
          | @syntax.TypeDesc::Alias(_)
          | @syntax.TypeDesc::Error(@syntax.ExceptionDecl::NoPayload)
          | @syntax.TypeDesc::TupleStruct(_) => ()
          @syntax.TypeDesc::Error(@syntax.ExceptionDecl::EnumPayload(constrs))
          | @syntax.TypeDesc::Variant(constrs)
          | @syntax.TypeDesc::ExtensibleEnum(Some(constrs))
          | @syntax.TypeDesc::ExtendEnum(constructors=constrs, ..) =>
            constrs.each(constr => {
              let previous = skip_docstrings_before(constr.loc.start)
                .map(make_doc)
                .unwrap_or(@syntax.DocString::empty())
              constr.doc = previous
            })
          @syntax.TypeDesc::Record(fields~, ..) =>
            fields.each(field => {
              let previous = skip_docstrings_before(field.loc.start)
                .map(make_doc)
                .unwrap_or(@syntax.DocString::empty())
              field.doc = previous
            })
        }
      }
      @syntax.Impl::TopFuncDef(fun_decl~, ..) => fun_decl.doc = doc
      @syntax.Impl::TopLetDef(..) as ld => ld.doc = doc
      @syntax.Impl::TopExpr(..) => ()
      @syntax.Impl::TopImplRelation(..) as imp => imp.doc = doc
      @syntax.Impl::TopTest(..) as test_ => test_.doc = doc
      @syntax.Impl::TopTrait(decl) => decl.doc = doc
      @syntax.Impl::TopView(..) as view => view.doc = doc
      @syntax.Impl::TopImpl(..) as imp => imp.doc = doc
      @syntax.Impl::TopUsing(..) as using_stmt => using_stmt.doc = doc
      @syntax.Impl::TopExtend(..) as extend_stmt => extend_stmt.doc = doc
      @syntax.Impl::TopImport(..) as import_stmt => import_stmt.doc = doc
    }
    skip_docstrings_before(toplevel.loc().end) |> ignore
  }
}

///|
fn scan_brace_block(tokens : @tokens.Triples, start_idx : Int) -> (Int?, Bool) {
  let mut depth = 0
  let mut has_arrow = false
  let mut i = start_idx
  while i < tokens.length() {
    let (tok, _, _) = tokens[i]
    if tok is @tokens.Token::LBRACE {
      depth += 1
    } else if tok is @tokens.Token::RBRACE {
      depth -= 1
      if depth == 0 {
        return (Some(i), has_arrow)
      }
    } else if depth == 1 && tok is @tokens.Token::FAT_ARROW {
      has_arrow = true
    }
    i += 1
  }
  (None, has_arrow)
}

///|
fn find_match_body_end(tokens : @tokens.Triples, match_idx : Int) -> Int? {
  let mut first_end : Int? = None
  let mut i = match_idx + 1
  while i < tokens.length() {
    let (tok, _, _) = tokens[i]
    if tok is @tokens.Token::LBRACE {
      let (end_idx, has_arrow) = scan_brace_block(tokens, i)
      match end_idx {
        Some(end) => {
          if first_end is None {
            first_end = Some(end)
          }
          if has_arrow {
            return Some(end)
          }
          i = end + 1
          continue
        }
        None => return None
      }
    }
    i += 1
  }
  first_end
}

///|
fn insert_match_parens_tokens(tokens : @tokens.Triples) -> @tokens.Triples {
  let insertions : Array[(Int, @tokens.Triple)] = Array::new(capacity=0)
  for i in 0..<tokens.length() {
    let (tok, start, _) = tokens[i]
    if tok is @tokens.Token::MATCH {
      match find_match_body_end(tokens, i) {
        Some(end_idx) => {
          let (_, _, end_pos) = tokens[end_idx]
          insertions.push((i, (@tokens.Token::LPAREN, start, start)))
          insertions.push(
            (end_idx + 1, (@tokens.Token::RPAREN, end_pos, end_pos)),
          )
        }
        None => ()
      }
    }
  }
  if insertions.length() == 0 {
    return tokens
  }
  insertions.sort_by((a, b) => a.0 - b.0)
  let out = Array::new(capacity=tokens.length() + insertions.length())
  let mut ins_idx = 0
  for idx in 0..<tokens.length() {
    while ins_idx < insertions.length() && insertions[ins_idx].0 == idx {
      out.push(insertions[ins_idx].1)
      ins_idx += 1
    }
    out.push(tokens[idx])
  }
  while ins_idx < insertions.length() {
    out.push(insertions[ins_idx].1)
    ins_idx += 1
  }
  out
}

///|
fn parse_moonyacc_tokens(
  tokens : @tokens.Triples,
) -> (@syntax.Impls, Array[@basic.Report]) {
  (@yacc_parser.structure(tokens), []) catch {
    @yacc_parser.UnexpectedEndOfInput(pos, _) =>
      (
        @list.empty(),
        [
          @basic.Report::{
            loc: { start: pos, end: pos, },
            msg: "Unexpected end of file.",
          },
        ],
      )
    @yacc_parser.UnexpectedToken(token, (start, end), _) =>
      (
        @list.empty(),
        [
          @basic.Report::{
            loc: { start, end, },
            msg: "Unexpected `\{@debug.to_string(token)}`.",
          },
        ],
      )
  }
}

///|
fn parse_moonyacc_with_match_parens(
  source : String,
  name : String,
) -> (@syntax.Impls, Array[@basic.Report]) {
  let { tokens, docstrings, .. } = @lexer.tokens_from_string_with_utf16_location(
    source[:],
    comment=true,
    name~,
  )
  let tokens = tokens.filter(fn(triple) {
    !(triple.0 is @tokens.Token::NEWLINE ||
    triple.0 is @tokens.Token::COMMENT(_))
  })
  let tokens = insert_match_parens_tokens(tokens)
  let (impls, reports) = parse_moonyacc_tokens(tokens)
  attach_docstrings_for_lint(docstrings, impls)
  (impls, reports)
}

///|
fn has_unexpected_match(reports : Array[@basic.Report]) -> Bool {
  for _, report in reports {
    if report.msg.find("Unexpected `MATCH`") is Some(_) {
      return true
    }
  }
  false
}

///|
priv struct InterpolationParser {
  reports : Array[@basic.Report]
}

///|
impl @syntax.MapVisitor for InterpolationParser with fn visit_InterpElem(
  env,
  elem,
) {
  match elem {
    @syntax.InterpElem::Source({ source, loc, }) => {
      // Upstream preserves interpolation bodies as unparsed source. Parse them
      // here so lint visitors see them, using the surrounding UTF-16 positions.
      let { tokens, errors, .. } = @lexer.tokens_from_string_with_utf16_location(
        source[:],
        name=loc.start.fname,
        start_pos=loc.start,
        is_interpolation=true,
        comment=false,
      )
      for (start, end, err) in errors {
        env.reports.push(@basic.Report::{
          loc: { start, end, },
          msg: err.to_string(),
        })
      }
      let (expr, reports) = @handrolled_parser.parse_expr(tokens)
      env.reports.append(reports)
      @syntax.InterpElem::Expr(expr=env.visit_Expr(expr), loc~)
    }
    _ => env.base().visit_InterpElem(elem)
  }
}

///|
fn parse_interpolations(
  impls : @syntax.Impls,
  reports : Array[@basic.Report],
) -> (@syntax.Impls, Array[@basic.Report]) {
  let env = InterpolationParser::{ reports, }
  (impls.map(impl_ => env.visit_Impl(impl_)), reports)
}

///|
pub fn parse_string_for_lint(
  source : String,
  name? : String = "",
  parser? : @parser.Parser = Handrolled,
) -> (@syntax.Impls, Array[@basic.Report]) {
  let normalized = source
    |> normalize_range_lt_inclusive
    |> normalize_legacy_syntax
  // All fixes slice MoonBit strings using UTF-16 offsets. The parser facade
  // defaults to Unicode scalar offsets, so lex explicitly in UTF-16 here.
  let { tokens, docstrings, errors, } = @lexer.tokens_from_string_with_utf16_location(
    normalized[:],
    name~,
    comment=true,
  )
  let (impls, diagnostics) = match parser {
    Handrolled => @handrolled_parser.parse(tokens)
    MoonYacc =>
      parse_moonyacc_tokens(
        tokens.filter(triple => !is_parser_trivia_token(triple.0)),
      )
  }
  attach_docstrings_for_lint(docstrings, impls)
  let reports = errors.filter_map(error => {
    let (start, end, err) = error
    match err {
      @lexer.LexicalError::Reserved_keyword(_) => None
      _ => Some(@basic.Report::{ loc: { start, end, }, msg: err.to_string(), })
    }
  })
  reports.append(diagnostics)
  if parser is MoonYacc && errors.is_empty() && has_unexpected_match(reports) {
    let (fallback, errors) = parse_moonyacc_with_match_parens(normalized, name)
    if errors.is_empty() {
      return parse_interpolations(fallback, errors)
    }
  }
  parse_interpolations(impls, reports)
}
