import <string>;

int main() {
  std::string s(3, 'b');
  return s == "bbb" ? 0 : 1;
}
