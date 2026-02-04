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
      sb..write_view(suffix)
      sb.to_string()
    }
    Err(_) => source
  }
}

///|
pub fn parse_string_for_lint(
  source : String,
  name? : String = "",
  parser? : @parser.Parser = Handrolled,
) -> (@syntax.Impls, Array[@basic.Report]) {
  let normalized = normalize_range_lt_inclusive(
    normalize_using_type_keyword(source),
  )
  @parser.parse_string(normalized, name~, parser~)
}
