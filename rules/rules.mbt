///|
pub fn rules() -> Array[@moonlint.Rule] {
  [
    match_try_question_rule(),
    string_literal_multiply_number_rule(),
    boolean_if_true_false_rule(),
    boolean_if_false_true_rule(),
    redundant_if_same_branch_rule(),
  ]
}
