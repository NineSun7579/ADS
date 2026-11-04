`timescale 1ns/1ps
// Full-field baseline table is retained; mode-specific values override its
// final geometry/ISP block. All writes are checked (including data-byte ACK).
// Completion requires actual 3808..380B reads, plus the HTS/VTS/PLL readback
// 380C/380D/380E/380F/3035/3036. No expected-value substitution.
module reg_config_c5 #(
    parameter SCCB_DIV=125, COLOR_BAR_TEST=0,
    parameter RESET_WAIT_CYCLES=125000 // >=5ms at the 25MHz configuration clock.
)(
    input clk_25M, camera_rstn, initial_en, start, mode720, timing720,
    output reg reg_conf_done, output reg config_error,
    output reg [15:0] actual_width, actual_height,
    // Sensor-side readback diagnostics, using the SAME SCCB read mechanism as
    // 3808..380B. o_pll = {0x3035, 0x3036}. Held at 0 until the readback
    // sequence completes, and cleared again if any read in it fails.
    output reg [15:0] o_hts, output reg [15:0] o_vts, output reg [15:0] o_pll,
    output i2c_sclk, inout i2c_sdat, output reg [8:0] reg_index,
    output restart_ready
);
    localparam IDLE=0, LAUNCH=1, WAIT_BUS=2, NEXT=3, FINISHED=4, RESET_WAIT=5;
    reg [2:0] state;
    reg latched_mode, latched_timing, reading, bus_start;
    reg [3:0] read_index;
    reg [23:0] reg_data;
    reg [31:0] reset_wait_count;
    // Readback order: 3808..380B (output geometry), 380C/380D (HTS),
    // 380E/380F (VTS), 3035/3036 (PLL). Same master, same sequence.
    reg [15:0] read_address;
    always @(*) case (read_index)
        4'd0: read_address=16'h3808; 4'd1: read_address=16'h3809;
        4'd2: read_address=16'h380A; 4'd3: read_address=16'h380B;
        4'd4: read_address=16'h380C; 4'd5: read_address=16'h380D;
        4'd6: read_address=16'h380E; 4'd7: read_address=16'h380F;
        4'd8: read_address=16'h3035; 4'd9: read_address=16'h3036;
        default: read_address=16'h3808;
    endcase
    wire [15:0] bus_address=reading ? read_address : reg_data[23:8];
    wire bus_done, bus_error, bus_busy;
    wire [7:0] bus_read;
    assign restart_ready=!bus_busy && (state==IDLE || state==FINISHED);
    cam5_sccb_master #(.DIV(SCCB_DIV)) master(
        .clk(clk_25M),.rst_n(camera_rstn),.start(bus_start),
        .read_not_write(reading),.address(bus_address),.write_data(reg_data[7:0]),
        .busy(bus_busy),.done(bus_done),.error(bus_error),.read_data(bus_read),
        .scl(i2c_sclk),.sda(i2c_sdat));
    always @(posedge clk_25M or negedge camera_rstn)
        if (!camera_rstn) begin
            state<=IDLE; reg_conf_done<=0; config_error<=0;
            actual_width<=0; actual_height<=0; reg_index<=0;
            o_hts<=0; o_vts<=0; o_pll<=0;
            latched_mode<=0; latched_timing<=0; reading<=0; read_index<=0; bus_start<=0;reset_wait_count<=0;
        end else begin
            bus_start<=0;
            if (start && restart_ready) begin
                state<=LAUNCH; reg_conf_done<=0; config_error<=0;
                actual_width<=0; actual_height<=0; reg_index<=0;
                o_hts<=0; o_vts<=0; o_pll<=0;
                latched_mode<=mode720; latched_timing<=timing720; reading<=0; read_index<=0;reset_wait_count<=0;
            end else case (state)
            IDLE: ;
            LAUNCH: if (initial_en) begin bus_start<=1; state<=WAIT_BUS; end
            WAIT_BUS: if (bus_done) begin
                if (bus_error) begin
                    config_error<=1; state<=FINISHED;
                    o_hts<=0; o_vts<=0; o_pll<=0;   // no partial readback
                end
                else begin
                    if (reading) case (read_index)
                        0: actual_width[15:8]<=bus_read;
                        1: actual_width[7:0]<=bus_read;
                        2: actual_height[15:8]<=bus_read;
                        3: actual_height[7:0]<=bus_read;
                        4: o_hts[15:8]<=bus_read;
                        5: o_hts[7:0]<=bus_read;
                        6: o_vts[15:8]<=bus_read;
                        7: o_vts[7:0]<=bus_read;
                        8: o_pll[15:8]<=bus_read;   // 0x3035
                        9: o_pll[7:0]<=bus_read;    // 0x3036
                    endcase
                    if(!reading && reg_index==1)begin
                        // Start the recovery interval only after the ACK-checked
                        // 3008=82 transaction has completed its STOP.
                        reset_wait_count<=0;state<=RESET_WAIT;
                    end else state<=NEXT;
                end
            end
            NEXT: begin
                if (reading) begin
                    if (read_index==4'd9) begin reg_conf_done<=1; state<=FINISHED; end
                    else begin read_index<=read_index+1'b1; state<=LAUNCH; end
                end else if (reg_index==(COLOR_BAR_TEST ? 357 :
                                         ((latched_mode && latched_timing) ? 358 : 356))) begin
                    reading<=1; read_index<=0; state<=LAUNCH;
                end else begin reg_index<=reg_index+1'b1; state<=LAUNCH; end
            end
            FINISHED: ;
            RESET_WAIT:begin
                if(reset_wait_count>=RESET_WAIT_CYCLES-1)begin
                    // Entries 2..101 are table holes, never bus transactions.
                    reg_index<=102;state<=LAUNCH;
                end else reset_wait_count<=reset_wait_count+1'b1;
            end
            endcase
        end
    always @(*) begin
        case (reg_index)
        0:reg_data=24'h310311; 1:reg_data=24'h300882;
        102:reg_data=24'h300842;103:reg_data=24'h310303;
        104:reg_data=24'h3017ff;105:reg_data=24'h3018ff;
        106:reg_data=24'h30341a;107:reg_data=24'h303713;
        108:reg_data=24'h310801;109:reg_data=24'h363036;
        110:reg_data=24'h36310e;111:reg_data=24'h3632e2;
        112:reg_data=24'h363312;113:reg_data=24'h3621e0;
        114:reg_data=24'h3704a0;115:reg_data=24'h37035a;
        116:reg_data=24'h371578;117:reg_data=24'h371701;
        118:reg_data=24'h370b60;119:reg_data=24'h37051a;
        120:reg_data=24'h390502;121:reg_data=24'h390610;
        122:reg_data=24'h39010a;123:reg_data=24'h373112;
        124:reg_data=24'h360008;125:reg_data=24'h360133;
        126:reg_data=24'h302d60;127:reg_data=24'h362052;
        128:reg_data=24'h371b20;129:reg_data=24'h471c50;
        130:reg_data=24'h3a1343;131:reg_data=24'h3a1800;
        132:reg_data=24'h3a19f8;133:reg_data=24'h363513;
        134:reg_data=24'h363603;135:reg_data=24'h363440;
        136:reg_data=24'h362201;137:reg_data=24'h3c0134;
        138:reg_data=24'h3c0428;139:reg_data=24'h3c0598;
        140:reg_data=24'h3c0600;141:reg_data=24'h3c0708;
        142:reg_data=24'h3c0800;143:reg_data=24'h3c091c;
        144:reg_data=24'h3c0a9c;145:reg_data=24'h3c0b40;
        146:reg_data=24'h381000;147:reg_data=24'h381110;
        148:reg_data=24'h381200;149:reg_data=24'h370864;
        150:reg_data=24'h400102;151:reg_data=24'h40051a;
        152:reg_data=24'h300000;153:reg_data=24'h3004ff;
        154:reg_data=24'h300e58;155:reg_data=24'h302e00;
        156:reg_data=24'h430060;157:reg_data=24'h501f01;
        158:reg_data=24'h440e00;159:reg_data=24'h5000a7;
        160:reg_data=24'h3a0f30;161:reg_data=24'h3a1028;
        162:reg_data=24'h3a1b30;163:reg_data=24'h3a1e26;
        164:reg_data=24'h3a1160;165:reg_data=24'h3a1f14;
        166:reg_data=24'h580023;167:reg_data=24'h580114;
        168:reg_data=24'h58020f;169:reg_data=24'h58030f;
        170:reg_data=24'h580412;171:reg_data=24'h580526;
        172:reg_data=24'h58060c;173:reg_data=24'h580708;
        174:reg_data=24'h580805;175:reg_data=24'h580905;
        176:reg_data=24'h580a08;177:reg_data=24'h580b0d;
        178:reg_data=24'h580c08;179:reg_data=24'h580d03;
        180:reg_data=24'h580e00;181:reg_data=24'h580f00;
        182:reg_data=24'h581003;183:reg_data=24'h581109;
        184:reg_data=24'h581207;185:reg_data=24'h581303;
        186:reg_data=24'h581400;187:reg_data=24'h581501;
        188:reg_data=24'h581603;189:reg_data=24'h581708;
        190:reg_data=24'h58180d;191:reg_data=24'h581908;
        192:reg_data=24'h581a05;193:reg_data=24'h581b06;
        194:reg_data=24'h581c08;195:reg_data=24'h581d0e;
        196:reg_data=24'h581e29;197:reg_data=24'h581f17;
        198:reg_data=24'h582011;199:reg_data=24'h582111;
        200:reg_data=24'h582215;201:reg_data=24'h582328;
        202:reg_data=24'h582446;203:reg_data=24'h582526;
        204:reg_data=24'h582608;205:reg_data=24'h582726;
        206:reg_data=24'h582864;207:reg_data=24'h582926;
        208:reg_data=24'h582a24;209:reg_data=24'h582b22;
        210:reg_data=24'h582c24;211:reg_data=24'h582d24;
        212:reg_data=24'h582e06;213:reg_data=24'h582f22;
        214:reg_data=24'h583040;215:reg_data=24'h583142;
        216:reg_data=24'h583224;217:reg_data=24'h583326;
        218:reg_data=24'h583424;219:reg_data=24'h583522;
        220:reg_data=24'h583622;221:reg_data=24'h583726;
        222:reg_data=24'h583844;223:reg_data=24'h583924;
        224:reg_data=24'h583a26;225:reg_data=24'h583b28;
        226:reg_data=24'h583c42;227:reg_data=24'h583dce;
        228:reg_data=24'h5180ff;229:reg_data=24'h5181f2;
        230:reg_data=24'h518200;231:reg_data=24'h518314;
        232:reg_data=24'h518425;233:reg_data=24'h518524;
        234:reg_data=24'h518609;235:reg_data=24'h518709;
        236:reg_data=24'h518809;237:reg_data=24'h518975;
        238:reg_data=24'h518a54;239:reg_data=24'h518be0;
        240:reg_data=24'h518cb2;241:reg_data=24'h518d42;
        242:reg_data=24'h518e3d;243:reg_data=24'h518f56;
        244:reg_data=24'h519046;245:reg_data=24'h5191f8;
        246:reg_data=24'h519204;247:reg_data=24'h519370;
        248:reg_data=24'h5194f0;249:reg_data=24'h5195f0;
        250:reg_data=24'h519603;251:reg_data=24'h519701;
        252:reg_data=24'h519804;253:reg_data=24'h519912;
        254:reg_data=24'h519a04;255:reg_data=24'h519b00;
        256:reg_data=24'h519c06;257:reg_data=24'h519d82;
        258:reg_data=24'h519e38;259:reg_data=24'h548001;
        260:reg_data=24'h548108;261:reg_data=24'h548214;
        262:reg_data=24'h548328;263:reg_data=24'h548451;
        264:reg_data=24'h548565;265:reg_data=24'h548671;
        266:reg_data=24'h54877d;267:reg_data=24'h548887;
        268:reg_data=24'h548991;269:reg_data=24'h548a9a;
        270:reg_data=24'h548baa;271:reg_data=24'h548cb8;
        272:reg_data=24'h548dcd;273:reg_data=24'h548edd;
        274:reg_data=24'h548fea;275:reg_data=24'h54901d;
        276:reg_data=24'h53811e;277:reg_data=24'h53825b;
        278:reg_data=24'h538308;279:reg_data=24'h53840a;
        280:reg_data=24'h53857e;281:reg_data=24'h538688;
        282:reg_data=24'h53877c;283:reg_data=24'h53886c;
        284:reg_data=24'h538910;285:reg_data=24'h538a01;
        286:reg_data=24'h538b98;287:reg_data=24'h558006;
        288:reg_data=24'h558340;289:reg_data=24'h558410;
        290:reg_data=24'h558910;291:reg_data=24'h558a00;
        292:reg_data=24'h558bf8;293:reg_data=24'h501d40;
        294:reg_data=24'h530008;295:reg_data=24'h530130;
        296:reg_data=24'h530210;297:reg_data=24'h530300;
        298:reg_data=24'h530408;299:reg_data=24'h530530;
        300:reg_data=24'h530608;301:reg_data=24'h530716;
        302:reg_data=24'h530908;303:reg_data=24'h530a30;
        304:reg_data=24'h530b04;305:reg_data=24'h530c06;
        306:reg_data=24'h502500;307:reg_data=24'h300802;
        308:reg_data=24'h303521;309:reg_data=24'h303669;
        310:reg_data=24'h3c0708;311:reg_data=24'h382046;
        312:reg_data=24'h382101;313:reg_data=24'h381431;
        314:reg_data=24'h381531;315:reg_data=24'h380000;
        316:reg_data=24'h380100;317:reg_data=24'h380200;
        318:reg_data=24'h380304;319:reg_data=24'h38040a;
        320:reg_data=24'h38053f;321:reg_data=24'h380607;
        322:reg_data=24'h38079b;323:reg_data=24'h380802;
        324:reg_data=24'h380980;325:reg_data=24'h380a01;
        326:reg_data=24'h380be0;327:reg_data=24'h380c07;
        328:reg_data=24'h380d68;329:reg_data=24'h380e03;
        330:reg_data=24'h380fd8;331:reg_data=24'h381306;
        332:reg_data=24'h361800;333:reg_data=24'h361229;
        334:reg_data=24'h370952;335:reg_data=24'h370c03;
        336:reg_data=24'h3a0201;337:reg_data=24'h3a03f3;
        338:reg_data=24'h3a0800;339:reg_data=24'h3a096f;
        340:reg_data=24'h3a0a00;341:reg_data=24'h3a0b5c;
        342:reg_data=24'h3a0e06;343:reg_data=24'h3a0d08;
        344:reg_data=24'h3a1401;345:reg_data=24'h3a15f3;
        346:reg_data=24'h400402;347:reg_data=24'h30021c;
        348:reg_data=24'h3006c3;349:reg_data=24'h471303;
        350:reg_data=24'h440704;351:reg_data=24'h460b37;
        352:reg_data=24'h460c20;353:reg_data=24'h483716;
        354:reg_data=24'h382404;355:reg_data=24'h5001a3;
        356:reg_data=24'h350300;357:reg_data=(COLOR_BAR_TEST ? 24'h503d80 : 24'h503d00);
        // 720p only (see the write-phase length below): ISP H offset,
        // matching the 100H's proven 1280x720 configuration.
        358:reg_data=24'h381110;
        default:reg_data=24'hffffff;
        endcase
        // 720p binning + ISP scaler crop, 2624x1456 -> 1280x720.
        // Retain 50K 3035/3036/3824 divisors (84MHz byte DVP /42MHz pixel
        // nominal). Match C6 HTS=1896,VTS=984 to avoid accumulating inter-camera
        // line-rate drift solely from a different programmed HTS. Board FPS unproven.
        if (latched_mode) case (reg_index)
        // Only the output size changes: the full readout window and the base
        // 0x3813 are kept, mirroring the 100H's working 1280x720 setup. The ISP
        // then scales the subsampled 1312x972 window down to 1280x720.
        323:reg_data=24'h380805;324:reg_data=24'h380900;
        325:reg_data=24'h380a02;326:reg_data=24'h380bd0;
        default: ;
        endcase
        // 720p line/frame time, applied to BOTH cameras. The 84 MHz byte clock
        // is kept: only HTS changes, from 1896 to 3800, because a 1280-pixel
        // line is 2560 byte clocks and 1896 could not clock it out at all.
        // 3800/84 MHz = 45.2 us per line, which also stays above the 41.0 us
        // merge row, so C5's two-slot page ring cannot be overrun. VTS stays
        // 984, giving both cameras the same 44.5 ms frame (22.5 fps).
        if (latched_timing) case (reg_index)
        // Keep the 50K board clock (0x21/0x69, 84 MHz byte clock): the 100H
        // PLL values (0x11/0x54, 56 MHz) stop BOTH cameras on this board
        // (measured: err 0x2502, aseen=0 bseen=0). Only HTS changes, 1896 ->
        // 3800, because a 1280-pixel line is 2560 byte clocks and 1896 cannot
        // clock it out. 3800/84 MHz = 45.2 us, above the 41.0 us merge row.
        327:reg_data=24'h380c0e;328:reg_data=24'h380dd8;
        default: ;
        endcase
    end
endmodule
