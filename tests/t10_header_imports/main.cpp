import <proj/a.h>;
int b_macro_seen();
int main() {
  std::vector<int> v = a_vec();
  (void)b_macro_seen();
  return (v.size() == 1 && v[0] == 7 && A_MACRO == 1) ? 0 : 1;
}
