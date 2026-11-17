import <vector>;
import <string>;
std::vector<int> make();
int main() { auto v = make(); std::string s(v.size(), 'x'); return s == "xxx" ? 0 : 1; }
