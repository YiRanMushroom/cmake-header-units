#pragma once
#if T16_DIR_DEF != 3 || T16_DEP_DEF != 4
#error "header unit built without the directory / link-interface definitions"
#endif
#if !defined(__FAST_MATH__) && !defined(_M_FP_FAST)
#error "header unit built without the target's compile options"
#endif
#define SUB_VALUE 3
