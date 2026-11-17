export module m;
// Re-exported: m's API uses std::vector, and importers of m (t03_other, which has no header units of its
// own) call its members.  A plain (non-exported) import is covered by the boundary probe m2.
export import <vector>;

export std::vector<int> make_numbers(int n) {
  std::vector<int> v;
  for (int i = 0; i < n; ++i) v.push_back(i * i);
  return v;
}

export int sum(std::vector<int> const& v) {
  int s = 0;
  for (int x : v) s += x;
  return s;
}
