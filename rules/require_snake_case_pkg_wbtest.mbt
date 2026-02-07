///|
test "is_snake_case valid" {
  inspect(is_snake_case("foo"), content="true")
  inspect(is_snake_case("foo_bar"), content="true")
  inspect(is_snake_case("foo_bar_baz"), content="true")
  inspect(is_snake_case("a1"), content="true")
  inspect(is_snake_case("foo2bar"), content="true")
  inspect(is_snake_case("my_pkg3"), content="true")
}

///|
test "is_snake_case invalid" {
  inspect(is_snake_case(""), content="false")
  inspect(is_snake_case("Foo"), content="false")
  inspect(is_snake_case("fooBar"), content="false")
  inspect(is_snake_case("foo-bar"), content="false")
  inspect(is_snake_case("foo__bar"), content="false")
  inspect(is_snake_case("_foo"), content="false")
  inspect(is_snake_case("foo_"), content="false")
  inspect(is_snake_case("1foo"), content="false")
  inspect(is_snake_case("FOO"), content="false")
  inspect(is_snake_case("foo.bar"), content="false")
}

///|
test "extract_pkg_dir_name" {
  inspect(extract_pkg_dir_name("foo.mbt"), content="None")
  inspect(extract_pkg_dir_name("cli/main.mbt"), content="Some(\"cli\")")
  inspect(
    extract_pkg_dir_name("src/foo_bar/baz.mbt"),
    content="Some(\"foo_bar\")",
  )
  inspect(
    extract_pkg_dir_name("myPackage/foo.mbt"),
    content="Some(\"myPackage\")",
  )
  inspect(
    extract_pkg_dir_name("a/b/camelCase/test.mbt"),
    content="Some(\"camelCase\")",
  )
}

///|
test "extract_file_stem" {
  inspect(extract_file_stem("foo.mbt"), content="Some(\"foo\")")
  inspect(extract_file_stem("cli/main.mbt"), content="Some(\"main\")")
  inspect(extract_file_stem("src/myFile.mbt"), content="Some(\"myFile\")")
  inspect(extract_file_stem("foo_bar.mbt"), content="Some(\"foo_bar\")")
  inspect(extract_file_stem("FooBar.mbt"), content="Some(\"FooBar\")")
  inspect(extract_file_stem("not_mbt.txt"), content="None")
}
