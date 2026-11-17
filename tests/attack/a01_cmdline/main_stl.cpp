import <vector>;
import <string>;
import <iostream>;
int main() { std::vector<std::string> v{"a", "b"}; std::cout << v.size() << '\n'; return v.size() == 2 ? 0 : 1; }
