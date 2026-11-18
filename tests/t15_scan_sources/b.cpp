import <vector>;
import <string>;
int b_value() { std::string s = "hello"; std::vector<char> v(s.begin(), s.end()); return static_cast<int>(v.size()); }
