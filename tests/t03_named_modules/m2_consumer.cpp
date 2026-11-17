import m2;   // uses std::vector members without importing <vector> itself

int main() {
  auto v = make_numbers2(3);
  return v.size() == 3 && v[0] == 7 ? 0 : 1;
}
