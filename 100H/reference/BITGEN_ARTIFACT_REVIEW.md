# Bitgen artifact review — 2026-11-03

The PowerShell wrapper exited with an error because its Process.ExitCode property
was empty after waiting. The wrapper failure is preserved and is not reclassified
as an observed zero process exit code. No retry was performed.

Independent post-run checks:
- All 843 independently reviewed launch-pin SHA256 values still match.
- Vendor stdout says Generate Bitstream done and gen_bit_stream successfully.
- Stage run.log and top.bgr independently record programming-file completion.
- top.bgr identifies the same reviewed work_ctrlchain8_seed62/place_route/top_pnr.adf.
- Tool: Fabric Compiler 2022.2-SP6.4 build 146967.
- top.sbit: 3791112 bytes; SHA256
  3ccdaa213355d9cf1955701993d7e1a3b8826f48fde04d545855ab3712abf50f.

Artifact path:
work_bitgen_ctrlchain8_seed62/generate_bitstream/top.sbit

Verdict: programming artifact generated with consistent reviewed inputs and vendor
completion evidence. Wrapper process-exit collection remains defective. This is
not hardware validation, complete I/O signoff or permission to flash. Existing
62 input and 71 output constraint warnings remain. Board remains original v10.
