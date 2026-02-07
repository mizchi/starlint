///|
fn is_ident_char(c : UInt16) -> Bool {
  (('a' : UInt16) <= c && c <= ('z' : UInt16)) ||
  (('A' : UInt16) <= c && c <= ('Z' : UInt16)) ||
  (('0' : UInt16) <= c && c <= ('9' : UInt16)) ||
  c == ('_' : UInt16)
}

///|
fn normalize_using_type_keyword(source : String) -> String {
  let mut output = source
  let mut offset = 0
  while offset < output.length() {
    let view_result : Result[StringView, Error] = try? output[offset:]
    match view_result {
      Ok(view) =>
        match view.find("using") {
          None => break
          Some(rel) => {
            let using_pos = offset + rel
            if using_pos > 0 && is_ident_char(output[using_pos - 1]) {
              offset = using_pos + 5
              continue
            }
            let using_end = using_pos + 5
            if using_end < output.length() && is_ident_char(output[using_end]) {
              offset = using_end
              continue
            }
            let after_using_result : Result[StringView, Error] = try? output[using_pos:]
            let brace_rel = match after_using_result {
              Ok(after_using) => after_using.find("{")
              Err(_) => None
            }
            match brace_rel {
              None => break
              Some(rel_brace) => {
                let brace_pos = using_pos + rel_brace
                let after_brace_result : Result[StringView, Error] = try? output[brace_pos:]
                let close_rel = match after_brace_result {
                  Ok(after_brace) => after_brace.find("}")
                  Err(_) => None
                }
                match close_rel {
                  None => break
                  Some(rel_close) => {
                    let close_pos = brace_pos + rel_close
                    let prefix_result : Result[StringView, Error] = try? output[:brace_pos +
                      1]
                    let mid_result : Result[StringView, Error] = try? output[brace_pos +
                      1:close_pos]
                    let suffix_result : Result[StringView, Error] = try? output[close_pos:]
                    match (prefix_result, mid_result, suffix_result) {
                      (Ok(prefix), Ok(mid), Ok(suffix)) => {
                        let mid_replaced = mid
                          .to_string()
                          .replace_all(old="type ", new="     ")
                        let sb = StringBuilder::new()
                        sb
                        ..write_view(prefix)
                        ..write_string(mid_replaced)
                        ..write_view(suffix)
                        output = sb.to_string()
                        offset = close_pos + 1
                      }
                      _ => break
                    }
                  }
                }
              }
            }
          }
        }
      Err(_) => break
    }
  }
  output
}

///|
fn normalize_range_lt_inclusive(source : String) -> String {
  // TODO: parser が `..<=` を対応したら、この正規化を削除する。
  let view = source[:]
  match view.find("..<=") {
    None => return source
    Some(_) => ()
  }
  let lex_result = @lexer.tokens_from_string_with_utf16_location(
    source,
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
      let prefix_result : Result[StringView, Error] = try? source[last:start_idx]
      match prefix_result {
        Ok(prefix) => {
          changed = true
          sb..write_view(prefix)..write_string("..= ")
          last = end_idx
        }
        Err(_) => return source
      }
    }
  }
  if !changed {
    return source
  }
  let suffix_result : Result[StringView, Error] = try? source[last:]
  match suffix_result {
    Ok(suffix) => {
      sb.write_view(suffix)
      sb.to_string()
    }
    Err(_) => source
  }
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
      content: comments.map(p => match p.1.content {
        [.. "///|", .. remain] | [.. "///", .. remain] => remain.to_string()
        _ => panic()
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
          | @syntax.TypeDesc::Extern
          | @syntax.TypeDesc::Newtype(_)
          | @syntax.TypeDesc::Alias(_)
          | @syntax.TypeDesc::Error(
            @syntax.ExceptionDecl::NoPayload
            | @syntax.ExceptionDecl::SinglePayload(_)
          )
          | @syntax.TypeDesc::TupleStruct(_) => ()
          @syntax.TypeDesc::Error(@syntax.ExceptionDecl::EnumPayload(constrs))
          | @syntax.TypeDesc::Variant(constrs) =>
            constrs.each(constr => {
              let previous = skip_docstrings_before(constr.loc.start)
                .map(make_doc)
                .unwrap_or(@syntax.DocString::empty())
              constr.doc = previous
            })
          @syntax.TypeDesc::Record(fields) =>
            fields.each(field => {
              let previous = skip_docstrings_before(field.loc.start)
                .map(make_doc)
                .unwrap_or(@syntax.DocString::empty())
              field.doc = previous
            })
        }
      }
      @syntax.Impl::TopFuncDef(fun_decl~, ..) => fun_decl.doc = doc
      @syntax.Impl::TopFuncAlias(..) as fa => fa.doc = doc
      @syntax.Impl::TopLetDef(..) as ld => ld.doc = doc
      @syntax.Impl::TopExpr(..) => ()
      @syntax.Impl::TopImplRelation(..) as imp => imp.doc = doc
      @syntax.Impl::TopTest(..) as test_ => test_.doc = doc
      @syntax.Impl::TopTrait(decl) => decl.doc = doc
      @syntax.Impl::TopBatchTypeAlias(..) as decl => decl.doc = doc
      @syntax.Impl::TopBatchTraitAlias(..) as decl => decl.doc = doc
      @syntax.Impl::TopView(..) as view => view.doc = doc
      @syntax.Impl::TopImpl(..) as imp => imp.doc = doc
      @syntax.Impl::TopUsing(..) as using_stmt => using_stmt.doc = doc
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
            loc: { start: pos, end: pos },
            msg: "Unexpected end of file.",
          },
        ],
      )
    @yacc_parser.UnexpectedToken(token, (start, end), _) =>
      (
        @list.empty(),
        [@basic.Report::{ loc: { start, end }, msg: "Unexpected `\{token}`." }],
      )
  }
}

///|
fn parse_moonyacc_with_match_parens(
  source : String,
  name : String,
) -> (@syntax.Impls, Array[@basic.Report]) {
  let { tokens, docstrings, .. } = @lexer.tokens_from_string(
    source,
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
pub fn parse_string_for_lint(
  source : String,
  name? : String = "",
  parser? : @parser.Parser = Handrolled,
) -> (@syntax.Impls, Array[@basic.Report]) {
  let normalized = source
    |> normalize_using_type_keyword
    |> normalize_range_lt_inclusive
  let (impls, reports) = @parser.parse_string(normalized, name~, parser~)
  if reports.length() > 0 {
    match parser {
      @parser.Parser::MoonYacc =>
        if has_unexpected_match(reports) {
          // Retry with match expressions wrapped in parens for infix contexts.
          let (retry_impls, retry_reports) = parse_moonyacc_with_match_parens(
            normalized, name,
          )
          if retry_reports.length() == 0 {
            return (retry_impls, retry_reports)
          }
        }
      _ => ()
    }
  }
  (impls, reports)
}
