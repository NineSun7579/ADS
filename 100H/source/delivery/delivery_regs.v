`timescale 1ns/1ps
// Six-camera lease registers. All metadata and holds are in clk's domain.
module delivery_regs #(
    parameter [31:0] BASE=32'h40020000,
    parameter [31:0] DEST=32'h0a000000, THUMB_DEST=32'h0a200000,
    parameter integer WIDTH=640, HEIGHT=480, OUT_HEIGHT=640
) (
    input wire clk, rst,
    input wire [31:0] s_awaddr, s_wdata, s_araddr,
    input wire [3:0] s_wstrb,
    input wire s_awvalid, s_wvalid, s_bready, s_arvalid, s_rready,
    output wire s_awready, s_wready, s_arready,
    output reg s_bvalid, s_rvalid,
    output reg [1:0] s_bresp, s_rresp,
    output reg [31:0] s_rdata,
    output wire [5:0] capture_hold,
    input wire [191:0] camera_prev_base, camera_bank0, camera_bank1, camera_sequence,
    input wire [11:0] camera_published,
    input wire [5:0] camera_writer_idle, camera_pending, camera_flush, camera_dma_idle,
    input wire [5:0] camera_cmd_valid, camera_awvalid, camera_wvalid, camera_abort,
    output reg cmd_valid,
    input wire cmd_ready, core_busy, core_done, core_error, core_config_error,
    output wire [31:0] cmd_src,
    output reg [31:0] cmd_dst,
    output reg selected_mode
);
    reg aw_have, w_have;
    reg [31:0] aw_addr, w_data;
    reg [3:0] w_strb;
    reg held, frozen, completed, failed;
    reg [2:0] selected_camera, lease_camera;
    reg selected_bank, lease_bank;
    reg [5:0] quiet;
    reg [31:0] frozen_base, frozen_sequence, epoch, cycles, last_cycles, jobs_done;
    wire [2:0] active_camera=held ? lease_camera : selected_camera;
    wire [31:0] prev_base=camera_prev_base[active_camera*32 +: 32];
    wire [31:0] bank0=camera_bank0[active_camera*32 +: 32];
    wire [31:0] bank1=camera_bank1[active_camera*32 +: 32];
    wire [1:0] pub=camera_published[active_camera*2 +: 2];
    wire [31:0] expected_bank0=32'h00800000+active_camera*32'h00400000;
    wire bank_config_ok=bank0==expected_bank0 && bank1==expected_bank0+32'h00200000;
    wire published=bank_config_ok && ((prev_base==bank0 && pub[0]) ||
                                                   (prev_base==bank1 && pub[1]));
    wire drain_idle=camera_writer_idle[active_camera] && camera_dma_idle[active_camera] &&
        !camera_pending[active_camera] && !camera_flush[active_camera] &&
        !camera_cmd_valid[active_camera] && !camera_awvalid[active_camera] &&
        !camera_wvalid[active_camera] && !camera_abort[active_camera];
    // The freeze decision and the start-command publication check are taken
    // from registers: active_camera -> 6-way metadata mux -> publication
    // compare -> frozen_base/cycles CE failed setup. freeze_go/freeze_base/
    // freeze_sequence are the exact original freeze condition and payload
    // sampled one clock earlier; published_q is published one clock old.
    reg freeze_go, published_q;
    reg [31:0] freeze_base, freeze_sequence;
    wire busy=core_busy || cmd_valid;
    wire quarantined=!core_busy && !cmd_valid && !cmd_ready && !core_config_error;
    wire selector_locked=held || busy || quarantined;
    function [31:0] destination;
        input mode;
        input [2:0] cam;
        input bank;
        reg [2:0] slot;
        begin
            // Preserve C5 bank0 addresses and reserve disjoint fixed-size slots.
            slot=cam==4 ? 0 : (cam<4 ? cam+1'b1 : 5);
            if(mode) destination=THUMB_DEST+slot*32'h00080000+bank*32'h00040000;
            else if(cam==4 && !bank) destination=DEST;
            else destination=32'h0b000000+cam*32'h00400000+bank*32'h00200000;
        end
    endfunction
    wire [31:0] allowed_dest=destination(selected_mode,selected_camera,selected_bank);
    assign capture_hold=held ? (6'b000001 << lease_camera) : 6'd0;
    assign cmd_src=frozen_base;
    assign s_awready=!rst && !aw_have && !s_bvalid;
    assign s_wready=!rst && !w_have && !s_bvalid;
    assign s_arready=!rst && !s_rvalid;
    always @(posedge clk) begin
        if(rst) begin
            aw_have<=0; w_have<=0; s_bvalid<=0; s_rvalid<=0;
            s_bresp<=0; s_rresp<=0; s_rdata<=0; aw_addr<=0; w_data<=0; w_strb<=0;
            held<=0; frozen<=0; quiet<=0; frozen_base<=0; frozen_sequence<=0;
            selected_camera<=4; lease_camera<=4; selected_bank<=0; lease_bank<=0;
            completed<=0; failed<=0; epoch<=0; cycles<=0; last_cycles<=0; jobs_done<=0;
            cmd_valid<=0; cmd_dst<=DEST; selected_mode<=0;
            freeze_go<=0; published_q<=0; freeze_base<=0; freeze_sequence<=0;
        end else begin
            published_q<=published;
            freeze_go<=held && !frozen && drain_idle && !(quiet<32) &&
                       (published || lease_camera==0 || lease_camera==2 || lease_camera==3);
            freeze_base<=prev_base;
            freeze_sequence<=camera_sequence[lease_camera*32 +: 32];
            if(s_awvalid && s_awready) begin aw_have<=1; aw_addr<=s_awaddr; end
            if(s_wvalid && s_wready) begin w_have<=1; w_data<=s_wdata; w_strb<=s_wstrb; end
            if(s_bvalid && s_bready) s_bvalid<=0;
            if(s_rvalid && s_rready) s_rvalid<=0;
            if(cmd_valid && cmd_ready) cmd_valid<=0;
            if(!held) begin frozen<=0; quiet<=0; end
            else if(!frozen) begin
                if(!drain_idle) quiet<=0;
                else if(quiet<32) quiet<=quiet+1'b1;
                if(freeze_go) begin
                    frozen<=1; frozen_base<=freeze_base;
                    frozen_sequence<=freeze_sequence;
                end
            end
            if(core_busy) cycles<=cycles+1'b1;
            if(core_done) begin
                completed<=1; failed<=core_error; last_cycles<=cycles; jobs_done<=jobs_done+1'b1;
            end
            if(aw_have && w_have && !s_bvalid) begin
                aw_have<=0; w_have<=0; s_bvalid<=1; s_bresp<=0;
                case(aw_addr)
                    BASE+32'h20: if(w_strb[0]) begin
                        if(!w_data[0] && busy) s_bresp<=2;
                        else if(w_data[1] && (!w_data[0] || !frozen ||
                                 !published_q || !cmd_ready || busy)) s_bresp<=2;
                        else begin
                            held<=w_data[0];
                            if(!w_data[0]) begin frozen<=0; quiet<=0; end
                            if(w_data[0] && !held) begin
                                lease_camera<=selected_camera; lease_bank<=selected_bank;
                                epoch<=epoch+1'b1; completed<=0; failed<=0;
                            end
                            if(w_data[1]) begin cmd_valid<=1; completed<=0; failed<=0; cycles<=0; end
                        end
                    end
                    BASE+32'h24: begin
                        // Write-1 abandons a quiescent stale lease: the host died, or
                        // a failed switch rolled back by re-asserting the hold and never
                        // released it. Refused while anything is in flight, so it can
                        // never interrupt a healthy capture. `epoch` is deliberately
                        // untouched: the host validates reg(0x50)==epoch+1 per acquire.
                        if(w_strb[0] && w_data[0]) begin
                            if(busy || cmd_valid || !drain_idle) s_bresp<=2;
                            else begin held<=0; frozen<=0; quiet<=0; end
                        end else s_bresp<=2;
                    end
                    BASE+32'h40: begin
                        if(busy || w_strb!=4'hf || w_data!=allowed_dest) s_bresp<=2;
                        else cmd_dst<=w_data;
                    end
                    BASE+32'hb0: begin
                        if(selector_locked || w_strb!=4'hf || w_data>1) s_bresp<=2;
                        else begin
                            selected_mode<=w_data[0];
                            cmd_dst<=destination(w_data[0],selected_camera,selected_bank);
                            completed<=0; failed<=0; cycles<=0; last_cycles<=0;
                        end
                    end
                    BASE+32'hc0: begin
                        if(selector_locked || w_strb!=4'hf || w_data>5) s_bresp<=2;
                        else begin
                            selected_camera<=w_data[2:0];
                            cmd_dst<=destination(selected_mode,w_data[2:0],selected_bank);
                            completed<=0; failed<=0;
                        end
                    end
                    BASE+32'hd0: begin
                        if(selector_locked || w_strb!=4'hf || w_data>1) s_bresp<=2;
                        else begin
                            selected_bank<=w_data[0];
                            cmd_dst<=destination(selected_mode,selected_camera,w_data[0]);
                            completed<=0; failed<=0;
                        end
                    end
                    default: s_bresp<=2;
                endcase
            end
            if(s_arvalid && s_arready) begin
                s_rvalid<=1; s_rresp<=0;
                case(s_araddr)
                    BASE+32'h00: s_rdata<=32'h444c5632;
                    BASE+32'h10: s_rdata<={25'd0,quarantined,core_config_error,failed,completed,busy,frozen,held};
                    BASE+32'h20: s_rdata<={31'd0,held};
                    BASE+32'h24: s_rdata<=32'h0;   // write-1 abandon; reads back 0
                    BASE+32'h30: s_rdata<=frozen_base;
                    BASE+32'h40: s_rdata<=cmd_dst;
                    BASE+32'h50: s_rdata<=epoch;
                    BASE+32'h60: s_rdata<=selected_mode ? (WIDTH/2)*(HEIGHT/2)*2 : WIDTH*OUT_HEIGHT*3;
                    BASE+32'h70: s_rdata<=last_cycles;
                    BASE+32'h80: s_rdata<=WIDTH*HEIGHT*2;
                    BASE+32'h90: s_rdata<=jobs_done;
                    BASE+32'ha0: s_rdata<=32'hf; // RGB, thumbnail, six-camera ownership, register snapshot
                    BASE+32'hb0: s_rdata<={31'd0,selected_mode};
                    BASE+32'hc0: s_rdata<={29'd0,held ? lease_camera : selected_camera};
                    BASE+32'hd0: s_rdata<={31'd0,held ? lease_bank : selected_bank};
                    BASE+32'he0: s_rdata<=frozen_sequence;
                    BASE+32'hf0: s_rdata<=32'h3f;
                    BASE+32'h100: s_rdata<=bank0;
                    BASE+32'h110: s_rdata<=bank1;
                    BASE+32'h120: s_rdata<={27'd0,!bank_config_ok,camera_flush[active_camera],frozen,
                                                    held && !published,held && !drain_idle};
                    default: begin s_rdata<=0; s_rresp<=2; end
                endcase
            end
        end
    end
endmodule
