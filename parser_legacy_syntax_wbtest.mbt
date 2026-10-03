///|
test "legacy normalization preserves offsets and literal text" {
  let source =
    #|fn main {
    #|  // try? f!() and g?()
    #|  let text = "try? f!() g?()"
    #|  let result = try? f!(1)
    #|  g?(2)
    #|}
  let normalized = normalize_legacy_syntax(source)
  inspect(normalized.length() == source.length(), content="true")
  inspect(
    normalized,
    content=(
      #|fn main {
      #|  // try? f!() and g?()
      #|  let text = "try? f!() g?()"
      #|  let result = try! f (1)
      #|  g (2)
      #|}
    ),
  )
}

///|
test "modern try bang and unary negation are unchanged" {
  let source = "fn main { let result = try! f(); let flag = !(true) }"
  inspect(normalize_legacy_syntax(source) == source, content="true")
}

///|
test "legacy normalization handles interpolation expressions" {
  let source =
    #|fn main { println("literal try? f!(): \{try? f!()}") }
  inspect(
    normalize_legacy_syntax(source),
    content=(
      #|fn main { println("literal try? f!(): \{try! f ()}") }
    ),
  )
}
