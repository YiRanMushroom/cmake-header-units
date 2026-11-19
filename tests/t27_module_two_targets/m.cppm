export module m;
export import <vector>;

export std::vector<int> make_numbers(int n) {
  std::vector<int> v;
  for (int i = 0; i < n; ++i) v.push_back(i);
  return v;
}
