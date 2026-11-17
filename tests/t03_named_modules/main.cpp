import m;
import <string>;
import <iostream>;

int main() {
  auto v = make_numbers(4);
  std::string s = std::to_string(sum(v));
  std::cout << "sum=" << s << '\n';
  return s == "14" ? 0 : 1;
}
