`timescale 1ns/1ps
// Read-only view of the native HDMI path on two spare LEDs (LED2/LED3 are the
// camera-init lamps, idle while HDMI is active). KEY3 steps through groups:
//   g0: A=MS7200 VS seen          B=MS7200 DE row ends seen
//   g1: A=qualified frame         B=META queued
//   g2: A=META on the wire        B=marked SOF released to the packetizer
//   g3: A=measure_bad (level)     B=capture fault (level)
//   g4: A=pixels flowing          B=frame admitted (level)
//   g5: A=first row is 1280 wide  B=every row has the same width
//   g6: A=960 rows per frame      B=480 rows per frame
//   g7: A=some row wider than 1280  B=some row narrower than 1280
//   g8: measured number in decimal (KEY4 picks which), see below
// g0..g4 lamps are "activity in the last ~0.25 s"; g5..g7 are the verdict on the
// last complete frame (steady lamp).
// g8: LED2 flashes idx+1 times (1 first-row width, 2 rows per frame, 3 widest
// row, 4 narrowest row), dark, then the number digit by digit, most significant
// first, no leading zeros: LED3 blinks once per unit of the digit (a digit 0 is
// one long blink); LED2 gives one short flash between digits. Long dark gap, repeat.
module native_diag_leds #(parameter DEBOUNCE=500000,PB=20,
    ON=12,OFF=12,LONG=40,IDXON=8,IDXOFF=8,SEP=8,GAP=40,ENDGAP=80)(
    input wire sys_clk,input wire rst_n,input wire active_async,
    input wire key_n,input wire key4_n,
    input wire [3:0] p_tog,input wire [2:0] p_lvl,input wire [3:0] o_tog,
    input wire [5:0] flags,
    input wire [12:0] v0,input wire [12:0] v1,input wire [12:0] v2,input wire [12:0] v3,
    output wire diag_on,output reg led_a,output reg led_b
);
    (* ASYNC_REG="TRUE" *) reg [10:0] s1,s2;
    (* ASYNC_REG="TRUE" *) reg [5:0] fs1;
    reg [5:0] fs2;
    (* ASYNC_REG="TRUE" *) reg [1:0] act_sync;
    reg [10:0] prev;
    wire [10:0] raw={o_tog,p_lvl,p_tog};
    reg [PB-1:0] prescale;
    wire tick=prescale=={PB{1'b0}};
    reg [3:0] hold [0:10];
    reg [10:0] lamp;
    integer i;
    // bits 0..3 and 7..10 are toggles (edge = event); bits 4..6 are levels.
    wire [10:0] ev=s2^prev;
    wire [10:0] trig={ev[10:7],s2[6:4],ev[3:0]};
    always @(posedge sys_clk or negedge rst_n) begin
        if(!rst_n)begin
            s1<=0;s2<=0;prev<=0;prescale<=0;lamp<=0;act_sync<=0;fs1<=0;fs2<=0;
            for(i=0;i<11;i=i+1)hold[i]<=0;
        end else begin
            s1<=raw;s2<=s1;prev<=s2;act_sync<={act_sync[0],active_async};
            fs1<=flags;fs2<=fs1;
            prescale<=prescale+1'b1;
            for(i=0;i<11;i=i+1)begin
                if(trig[i])hold[i]<=4'd12;
                else if(tick && hold[i]!=0)hold[i]<=hold[i]-1'b1;
                lamp[i]<=hold[i]!=0;
            end
        end
    end
    assign diag_on=act_sync[1];
    // KEY3 cycles the group, KEY4 cycles the read-out index (both debounced).
    (* ASYNC_REG="TRUE" *) reg [1:0] k_sync,k4_sync;
    reg k_stable,k4_stable;
    reg [$clog2(DEBOUNCE)-1:0] k_count,k4_count;
    reg [3:0] group;reg [1:0] vidx;
    wire press=!k_sync[1] && k_stable && k_count==DEBOUNCE-1;
    wire press4=!k4_sync[1] && k4_stable && k4_count==DEBOUNCE-1;
    always @(posedge sys_clk or negedge rst_n) begin
        if(!rst_n)begin
            k_sync<=2'b11;k_stable<=1;k_count<=0;group<=0;
            k4_sync<=2'b11;k4_stable<=1;k4_count<=0;vidx<=0;
        end else begin
            k_sync<={k_sync[0],key_n};k4_sync<={k4_sync[0],key4_n};
            if(k_sync[1]==k_stable)k_count<=0;
            else if(k_count==DEBOUNCE-1)begin k_stable<=k_sync[1];k_count<=0;end
            else k_count<=k_count+1'b1;
            if(k4_sync[1]==k4_stable)k4_count<=0;
            else if(k4_count==DEBOUNCE-1)begin k4_stable<=k4_sync[1];k4_count<=0;end
            else k4_count<=k4_count+1'b1;
            if(!act_sync[1])group<=0;
            else if(press)group<=(group==4'd8) ? 4'd0 : (group+1'b1);
            if(press4)vidx<=vidx+1'b1;
        end
    end
    // ---- read-out: the numbers change once per frame; accept a sample only
    // when two consecutive samples agree (they cross from the pixel clock).
    (* ASYNC_REG="TRUE" *) reg [12:0] va;
    reg [12:0] vb,vstable;
    reg [12:0] vsel;
    always @* begin
        case(vidx)
            2'd0:vsel=v0;2'd1:vsel=v1;2'd2:vsel=v2;default:vsel=v3;
        endcase
    end
    always @(posedge sys_clk) begin
        va<=vsel;vb<=va;
        if(va==vb)vstable<=vb;
    end
    // ---- decimal flasher ----
    localparam [3:0] P_LOAD=0,P_DABBLE=1,P_IDX_ON=2,P_IDX_OFF=3,P_IGAP=4,P_DSTART=5,
        P_PON=6,P_POFF=7,P_PLONG=8,P_DEND=9,P_DSEP=10,P_DGAP=11,P_END=12;
    reg [3:0] ph;reg [7:0] timer;reg [2:0] flash_left;reg [3:0] pl;reg [1:0] k;
    reg [2:0] nd;reg [15:0] bcd;reg [12:0] sh;reg [3:0] dcnt;reg [1:0] idxlatch;
    reg lv2,lv3;reg seq_start;
    function [15:0] adjust(input [15:0] x);
        integer j;reg [3:0] n;
        begin
            for(j=0;j<4;j=j+1)begin
                n=x[4*j+:4];
                adjust[4*j+:4]=(n>=4'd5)?(n+4'd3):n;
            end
        end
    endfunction
    wire [15:0] bcd_adj=adjust(bcd);
    wire [3:0] cur_digit=bcd[4*k+:4];
    wire [2:0] nd_next=(bcd[15:12]!=0)?3'd4:(bcd[11:8]!=0)?3'd3:(bcd[7:4]!=0)?3'd2:3'd1;
    always @(posedge sys_clk or negedge rst_n) begin
        if(!rst_n)begin
            ph<=P_LOAD;timer<=0;flash_left<=0;pl<=0;k<=0;nd<=1;bcd<=0;sh<=0;dcnt<=0;
            idxlatch<=0;lv2<=0;lv3<=0;seq_start<=0;
        end else begin
            seq_start<=0;
            case(ph)
                P_LOAD:begin
                    sh<=vstable;bcd<=16'd0;dcnt<=4'd0;idxlatch<=vidx;lv2<=0;lv3<=0;
                    seq_start<=1;ph<=P_DABBLE;
                end
                P_DABBLE:begin
                    bcd<={bcd_adj[14:0],sh[12]};sh<={sh[11:0],1'b0};dcnt<=dcnt+1'b1;
                    if(dcnt==4'd12)begin
                        ph<=P_IDX_ON;timer<=IDXON-1;flash_left<={1'b0,idxlatch}+3'd1;
                    end
                end
                P_IDX_ON:begin
                    lv2<=1;lv3<=0;
                    if(tick)begin
                        if(timer==0)begin ph<=P_IDX_OFF;timer<=IDXOFF-1;end
                        else timer<=timer-1'b1;
                    end
                end
                P_IDX_OFF:begin
                    lv2<=0;lv3<=0;
                    if(tick)begin
                        if(timer==0)begin
                            flash_left<=flash_left-1'b1;
                            if(flash_left==3'd1)begin ph<=P_IGAP;timer<=GAP-1;nd<=nd_next;end
                            else begin ph<=P_IDX_ON;timer<=IDXON-1;end
                        end else timer<=timer-1'b1;
                    end
                end
                P_IGAP:begin
                    lv2<=0;lv3<=0;
                    if(tick)begin
                        if(timer==0)begin k<=nd-3'd1;ph<=P_DSTART;end
                        else timer<=timer-1'b1;
                    end
                end
                P_DSTART:begin
                    if(cur_digit==4'd0)begin ph<=P_PLONG;timer<=LONG-1;end
                    else begin pl<=cur_digit;ph<=P_PON;timer<=ON-1;end
                end
                P_PON:begin
                    lv2<=0;lv3<=1;
                    if(tick)begin
                        if(timer==0)begin ph<=P_POFF;timer<=OFF-1;end
                        else timer<=timer-1'b1;
                    end
                end
                P_POFF:begin
                    lv2<=0;lv3<=0;
                    if(tick)begin
                        if(timer==0)begin
                            if(pl==4'd1)ph<=P_DEND;
                            else begin pl<=pl-1'b1;ph<=P_PON;timer<=ON-1;end
                        end else timer<=timer-1'b1;
                    end
                end
                P_PLONG:begin
                    lv2<=0;lv3<=1;
                    if(tick)begin
                        if(timer==0)ph<=P_DEND;
                        else timer<=timer-1'b1;
                    end
                end
                P_DEND:begin
                    lv2<=0;lv3<=0;
                    if(k==2'd0)begin ph<=P_END;timer<=ENDGAP-1;end
                    else begin k<=k-1'b1;ph<=P_DSEP;timer<=SEP-1;end
                end
                P_DSEP:begin
                    lv2<=1;lv3<=0;
                    if(tick)begin
                        if(timer==0)begin ph<=P_DGAP;timer<=GAP-SEP-1;end
                        else timer<=timer-1'b1;
                    end
                end
                P_DGAP:begin
                    lv2<=0;lv3<=0;
                    if(tick)begin
                        if(timer==0)ph<=P_DSTART;
                        else timer<=timer-1'b1;
                    end
                end
                default:begin  // P_END
                    lv2<=0;lv3<=0;
                    if(tick)begin
                        if(timer==0)ph<=P_LOAD;
                        else timer<=timer-1'b1;
                    end
                end
            endcase
        end
    end
    always @(posedge sys_clk) begin
        case(group)
            4'd0:begin led_a<=lamp[0];led_b<=lamp[1];end
            4'd1:begin led_a<=lamp[2];led_b<=lamp[3];end
            4'd2:begin led_a<=lamp[7];led_b<=lamp[8];end
            4'd3:begin led_a<=lamp[4];led_b<=lamp[5];end
            4'd4:begin led_a<=lamp[9];led_b<=lamp[6];end
            4'd5:begin led_a<=fs2[0];led_b<=fs2[1];end
            4'd6:begin led_a<=fs2[2];led_b<=fs2[3];end
            4'd7:begin led_a<=fs2[4];led_b<=fs2[5];end
            default:begin led_a<=lv2;led_b<=lv3;end
        endcase
    end
endmodule
