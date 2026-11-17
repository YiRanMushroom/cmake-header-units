#include <cstdio>
int imp_size(); int txt_size(); int imp_idl(); int txt_idl();
int main() {
  std::printf("imported: sizeof(vector<int>)=%d IDL=%d | textual: sizeof=%d IDL=%d\n", imp_size(), imp_idl(), txt_size(), txt_idl());
  return (imp_size() == txt_size() && imp_idl() == txt_idl()) ? 0 : 3;
}
