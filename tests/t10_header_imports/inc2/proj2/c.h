#pragma once
export import "d.h";
export import <vector>;
inline std::vector<int> c_vec() { return {d_val(), d_val()}; }
