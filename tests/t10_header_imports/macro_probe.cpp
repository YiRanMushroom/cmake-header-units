import <proj/a.h>;
// Does a macro of a header unit re-exported with 'export import' reach the importer? (reported, not required)
#ifdef B_MACRO
int b_macro_seen() { return 1; }
#else
int b_macro_seen() { return 0; }
#endif
