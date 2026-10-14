-- zzz_czx_treasury_guard: disable the unsafe AI-turn name overlay.
--
-- The source mod registers one FactionTurnStart callback per AI faction and
-- writes the ai_turns component tree from delayed callbacks. During a long AI
-- turn that tree is repeatedly rebuilt, so this non-essential label is safer
-- left disabled than kept as a native UI write path.
return
