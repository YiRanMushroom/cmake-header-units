import <vector>;
import <val.h>;

int main() {
  std::vector<int> v{1, 2};
  return v.size() == 2 && t24_val() == 24 ? 0 : 1;
}
