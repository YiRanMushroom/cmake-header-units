module;
#include <string>
export module pg;
import <vector>;
export int g() { std::vector<std::string> v{"a"}; return (int)v.size(); }
