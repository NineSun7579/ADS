# Independent ctrlchain8 mapping review

## Decision and boundary

**PASS for scoped offline mapping inspection and preparation of bitgen only.** Parent review is still required before running the prepared bitgen launcher. This is not board authorization, complete I/O timing signoff, formal physical/configuration equivalence, or certification of opaque vendor IP. The board is not accessed and must remain original OTA `v10seed61`.

The original `result.json` remains FAILED_CLOSED, correctly recording the earlier parser failure. Neither it, `prepared_plan.json`, nor earlier acceptance flags is rewritten. The new separate machine gate is `mapping_acceptance_independent.json`; its acceptance applies only to the hashes and limitations recorded here.

## Independently checked provenance

- `independent_mapping_review.py` performs only offline file reads and evidence writes; no vendor invocation, rerouting, deletion, packaging, or hardware operation.
- Rehashed all 826 prepared inputs: 825 identical. The only difference is the explicitly reviewed offline `physical_compare.py`: original `795519d82876743bf67656f1f67426fca90894d9f46e8d8b616604980bc93145`, corrected `6f55a1033e63c3b47960e72af23b1d02e5f56d1301233240b336c0345f6d789f`. The preserved original parser independently matches the original pinned hash. No source, IP, mapped ADF, PCF, PnR or STA/export Tcl change is excused by this exception.
- All 810 baseline source/IP hashes were rechecked against postaw. The only source delta is `source/preprocess/native_bev_lean_multiplier.sv`; existing camera, PCIe, META/descriptor, divider, fitter, and constraints remain unchanged. All 84 inherited regression evidence hashes also match. These are retained functional/model regressions, not a newly run physical equivalence proof.
- The 384120-character multiplier module excerpt is an exact substring of the current synthesis `top_syn.vm`, independently rehashed as `3f9639c2c19cd0ab826a5ae8021bf918fdf11980a5bab69a0c28d4d9f9fcb4ac`. Fresh-build logs connect this source project to the mapped input. This review does not claim a cryptographic proof that opaque ADF contents implement RTL.
- Input mapped ADF SHA256: `88695aba7c5a3de95e562f6a1a4596b2a8023a2675448e3ff07939061a0d7d45`; PCF: `8a56a03751aacdb3bc0bef4ad2a1faba72f3e3109694e6c66288e9990d513523`.
- Routed ADF: `3bb55d9551d6181930fb71615e356c7ec702e382a905e9c5ae9e225321ac5f81` (41992169 bytes). Full STA: `c65ceabf1f248abd3b399bf236638abe6251f4852fc60521536995b38f7e7bf2` (2469169178 bytes). Physical functional export: `bf0780d291262565ae0e8f56ee918527ea74b803f7498de52b8d0ecfe2ce3ba8` (72779941 bytes).
- Exact part is Logos2 PG2L100H, speed -6, FBG484. The PCF header, raw STA header, and saved vendor help agree on Fabric Compiler **2022.2-SP6.4 build 146967**. The launcher pins the current executable hash as well. The saved PnR commands differ only by appended `-max_ctrl_chain_length 8`, seed remains 62. STA and export logs/Tcl both read the same routed ADF above. No timing exception, period, clock group, false path, multicycle, source rebuild, or constraint edit is introduced by this experiment.

## Actual synthesis and physical pin evidence

`independent_mapping_pin_cones.json` reparses all 99074 exported V_* statements, checks statement coverage, and traces real D/CE/SR combinational fan-in. It stops at both synchronous **and asynchronous** FF outputs; it does not trace through registered control state or treat unresolved nets as safe. No explicit assign aliases occur in the physical export. Primitive parameters are retained in the records.

| Bank | Synthesis | Current routed export | Finding |
|---|---|---|---|
| hi | 72 GTP_DFF_E | 72 V_FFSYN, SR=0 | All D/CE cones have zero direct application-reset dependencies and zero unresolved leaves. |
| lo | 72 GTP_DFF_E | 72 V_FFSYN, SR=0 | Same; no reset merely moved into a combinational D/CE gate. |
| c_fix | 1 GTP_DFF | CLMA_21_270/FF1/FF, SR=0, CE=1 | D is carry/update/hold selection controlled by registered S_FIX, not direct reset; no unresolved leaf. |
| product | 144 GTP_DFF_RE, R=arithmetic_reset | 144 V_FFSYN | Every SR resolves through explicit V_BUF forwarding to **noninverted axi_rst**; every cell SET_RESET=RESET and LRS_EN=TRUE. D/CE/SR traces have zero unresolved leaves. |
| multiplier state | 6 one-hot FFs | CLMA_27_258, 6 V_FFSYN | All six SRs resolve noninverted to axi_rst. IDLE bit0 is SET/INIT1, the other five RESET/INIT0. |
| done | 1 GTP_DFF, reset in D | CLMS_93_211/FF1/FF | SR=0, CE=1 is intentional: its actual D LUT has I3=axi_rst, exported truth expression `~I3&I5`, so reset suppresses done. |
| consumed divider quotient | unchanged divider | 72 V_FFSYN | All 72 SRs resolve noninverted to axi_rst, SET_RESET=RESET, LRS_EN=TRUE; zero unresolved D/CE/SR leaves. |

146 RTL scratch bits become 145 FFs because hi[72] is assigned zero on both writes (`hi<=73'd0` and `{1'b0,new_hi[72:1]}`); it is not a missing reset endpoint. No helper-buffer alias is required for approval. `native_bev_reset_branch` is an identity, not proven physical buffering. Device GRS_EN startup configuration is not an application-reset connection.

`mul_busy` is not a renamed missing reset FF: fitter only declares/connects this output and never consumes it; the synthesized multiplier port list contains product/done but no busy. It is legitimately optimized out. Source reset semantics and inherited all-public-cycle multiplier tests still cover busy at RTL. State and operand FFs remain resettable, so scratch retains **sequential** dependence on reset through them; only direct combinational reset loading was removed.

The quotient port is 144 bits at RTL but fitter consumes only [71:0], with narrower subsequent reads. The physically retained 72 resettable bits are therefore expected, not evidence of dropped observable upper bits. This review makes no assertion about an externally exposed 144-bit divider port after top-level optimization.

## Retained subsystem evidence, not a new equivalence claim

The actual synthesis VM contains c5_native_descriptor, c5_native_raster_split, c5_aw_descriptor_buffer, four ov5640_reg variants, pcie_fifo, and native multiplier/divider/fitter modules. The physical export contains 161 FF Qs selected by native_meta, 2723 by descriptor, 15403 by ov5640, 5956 by pcie_fifo, and 364 by c5_runtime/split; representative cells/pins are retained in the cone evidence. Counts are overlapping substring inventories, **not** exhaustive subsystem equivalence checks or just wire-name counts.

Source inspection confirms native META geometry/type/epoch/sequence validation (`c5_optical_runtime.sv:264`), queued META/SOF split state (`c5_native_raster_split.sv:72`), and the existing full PCIe `tx_cnt==dma_total_beats` reset-before-increment priority (`pcie_fifo.v:607`). Source hashes, fresh synth/map provenance, retained physical FFs, and unchanged functional regression evidence jointly support retention. They do not prove every LUT or every camera/PCIe transaction correct in hardware. No new camera/PCIe/META redesign is approved here.

## Timing and control-chain inspection

The independent raw-summary scanner (not the corrected detailed-path parser) checks all ten summary sections: slow setup/hold/recovery/removal/pulse minima **0.043 / 0.250 / 0.713 / 0.295 / 0.011 ns**; fast **2.217 / 0.168 / 2.360 / 0.247 / 0.011 ns**. Every summary row has zero failing endpoints and zero total negative slack; raw report says All Constraints Met. The +0.043 setup and +0.011 pulse margins are small, not robustness guarantees.

The existing corrected full detailed scan records 314728 constrained-slack paths and 7076 default arrival-only paths. Arrival-only paths are not converted into timing passes. Reported STA RSCO/CECO maxima are eight; reset-launch paths number 18496. This independent review separately reconstructs forwarding graph depth from the current physical export: RSCO 6189 nodes/max8, CECO 2437 nodes/max8, consistent with the saved audit and former worst RSCO depth33. These count named ingress/forwarding/polarity stages in the functional export, not fabricated timing arcs. The STA path list is bounded by `-nworst 1 -max_path 15000`; neither its maxima nor the functional graph proves opaque-IP/configuration coverage.

**Constraints limitation remains material:** current STA emits 62 Timing-4086 input warnings and 71 Timing-4087 output warnings, including camera data/href/vsync, SCCB, perst_n and DDR-interface ports. One additional warning concerns license expiry. The inherited asynchronous clock groups and unconstrained I/O are not fixed or waived by this pass. No board-level timing closure or CDC/protocol acceptance is claimed. Satisfying a future complete-I/O signoff requires measured/interface-spec delays and CDC review, not relaxing clocks or calling arrival-only paths constrained.

## Prepared bitgen gate — NOT RUN

`bitgen_after_parent_review.tcl` is based on the existing successful `C:/nh_build/seed137/bitgen.tcl` and its successful `bitgen.log`: same exact part and `gen_bit_stream -input_db_file ... -force_to_run -create_bit_file TRUE`, changing only routed input. The output is expected at the new work directory's `generate_bitstream/top.sbit`; bitgen command success alone is not artifact acceptance.

`bitgen_after_parent_review.ps1` refuses to run without the explicit parent-review switch, validates pinned evidence/tool/script hashes, requires a previously unused bitgen work directory and 8GiB+512MiB free capacity, and invokes **only bitgen**. It performs no PnR, packaging, flashing, reboot, OTA, device query, or board test. Timeout leaves processes/logs for inspection and never retries or deletes. No launcher is run in this review; only PowerShell syntax is parsed offline.

Parent next step: review this scoped report and `mapping_acceptance_independent.json`. Only after that review, parent may explicitly authorize the prepared launcher. Full hardware acceptance remains a separate blocked scope with the missing-I/O/formal/board limitations above; the board must stay originalv10seed61.
