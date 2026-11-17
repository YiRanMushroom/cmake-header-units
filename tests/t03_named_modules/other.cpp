import m;

int main() {
  auto v = make_numbers(5);
  return (sum(v) == 30 && v.size() == 5) ? 0 : 1;
}
