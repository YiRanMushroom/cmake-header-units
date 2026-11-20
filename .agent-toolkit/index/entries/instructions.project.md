+++
title = "Instructions: read every entry listed here (and below) at the start of a session"
kind = "instructions"
keys = [ "instructions" ]
updated = "2026-11-18 21:16:55"
children = [ "instructions.general" ]
+++
Rules from the owner for every session in this project:
- Every task and every wait has a timeout of at most 3 minutes. A command or wait that may take longer is started with a timeout of at most 3 minutes and then checked again, by hand, every 3 minutes at most (look at its output or result files, say how it stands, decide to keep waiting or stop it). Never wait without a timeout: no bare Poll (or any wait) for commands started without being awaited -- their end may produce no event, and the session then hangs until the user writes (it happened 2026-11-19: about 8 minutes idle with all tests already finished). Wait for background work with a bounded loop instead: await Promise.race([work, sleep(<= 14 s)]) and repeat. Shell commands: +++
title = "Instructions: read every entry listed here (and below) at the start of a session"
kind = "instructions"
keys = [ "instructions" ]
updated = "2026-11-18 21:16:55"
children = [ "instructions.general" ]
+++
Rules from the owner for every session in this project:
...`.timeout(180000) at most (past it they move to the background, not killed: check them again); agents and test suites are checked at least every 3 minutes.
- Report at each milestone and whenever something is unexpected or slow: what is done, what is running, why it takes long.
- "Lean and fast" means: decide which features to support, write them mostly in one go, then adapt them bit by bit -- never dropping what should be supported.
- Measurements must be fast (owner, 2026-11-20): no full-build benchmarks that take minutes. Use the compiler's own report on single commands: clang -ftime-trace (Total Frontend / Source / Backend events), cl /d1reportTime or timing one cl command, GCC -ftime-report. A full build only when asked.
