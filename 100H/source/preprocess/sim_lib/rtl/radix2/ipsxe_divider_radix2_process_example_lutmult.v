
// divider process
//latency:DIVI_ADDQ_W+1(in this module)
module radix2_process
(
    clk,
    rst_n,
    clk_en,
    cnt,
    dividend,
    divisor,

    
    remainder_r,
    

    quotient_r

   );
   
parameter    DIVIDEND_W=8;
parameter    DIVISOR_W=8;

parameter    QUOTIENT_FRACT_W=0;

parameter    DIVI_ADDQ_W = 8;

parameter    CLK_PER_DIVISION = 1;

localparam   DIVI_ITR_CPD = (DIVI_ADDQ_W <= (CLK_PER_DIVISION))?1:(DIVI_ADDQ_W>((DIVI_ADDQ_W>>($clog2(CLK_PER_DIVISION)))*CLK_PER_DIVISION))?
    ((DIVI_ADDQ_W>>$clog2(CLK_PER_DIVISION))+1):(DIVI_ADDQ_W>>($clog2(CLK_PER_DIVISION)));
localparam   DIVI_W_ITR = 2*(DIVI_ADDQ_W+1)*DIVI_ITR_CPD;
localparam   DIVIDEND_W_ITR = (2*DIVI_ADDQ_W+1)*DIVI_ITR_CPD+1;

input        clk;
input        rst_n;
input        clk_en;

input [2:0]cnt;


input        [DIVIDEND_W-1:0] dividend;
input        [DIVISOR_W-1:0] divisor;


output   reg    [DIVISOR_W-1:0]remainder_r;

output   reg    [DIVIDEND_W-1:0]quotient_r;

wire   [(2*DIVI_ADDQ_W+1):0] dividend_2n; //2 sign bit
wire   [2*DIVI_ADDQ_W+1:0] divisor_2n; //2 sign bit
wire   [(DIVIDEND_W_ITR-1):0] dividend_itr;

reg    [(DIVIDEND_W_ITR-1):0] dividend_itr_r;
reg    [(DIVI_W_ITR-1):0] divisor_itr_r;
reg    [DIVISOR_W-1:0]   remainder;
reg    [DIVI_ADDQ_W-1:0] quotient;


wire   [DIVISOR_W-1:0] remainder_temp;

wire   [DIVIDEND_W-1:0] quotient_temp;

//iteration: clk per division not equal to 1

wire   [(DIVIDEND_W_ITR-2):0]dividend_itr_cpd;
wire   [DIVI_W_ITR-1:0]divisor_itr_cpd;

assign dividend_2n={{(2*DIVI_ADDQ_W+2-DIVIDEND_W){1'b0}},dividend};   


assign divisor_2n={{(DIVI_ADDQ_W-DIVISOR_W+2){1'b0}},divisor,{DIVI_ADDQ_W{1'b0}}};  //shift left DIVI_ADDQ_W bit

always@(posedge clk or negedge rst_n)
    if(!rst_n)begin
        dividend_itr_r <= {DIVIDEND_W_ITR {1'b0}};

    end
    else if(clk_en) begin
        
        dividend_itr_r <= dividend_itr;
    end
    else begin
    end

always@(posedge clk or negedge rst_n)
    if(!rst_n)begin
        divisor_itr_r <= {DIVI_W_ITR {1'b0}};
    end
    else if(clk_en) begin
        if (cnt == 0)begin
            divisor_itr_r[DIVI_W_ITR-1 : 2*(DIVI_ADDQ_W+1)] <=
            divisor_itr_r[(DIVI_W_ITR-1 - 2*DIVI_ADDQ_W-2):0];
            divisor_itr_r[2*DIVI_ADDQ_W+1:0] <= divisor_2n;
        end
        else begin
            divisor_itr_r <= divisor_itr_r;
        end
    end
    else begin
    end
    
     //iteration: clk per division not equal to 1
    assign  dividend_itr_cpd[2*DIVI_ADDQ_W:0] = (cnt == 0)?dividend_2n[2*DIVI_ADDQ_W:0]:dividend_itr_r[2*DIVI_ADDQ_W:0];
    assign  divisor_itr_cpd[2*DIVI_ADDQ_W+1:0] = (cnt == 0)?divisor_2n:divisor_itr_r[2*DIVI_ADDQ_W+1:0];
    genvar i;
    generate
        for(i=0;i<DIVI_ITR_CPD;i=i+1) begin: iteration_n
            if(i==0)begin
                iteration #(.DIVI_ADDQ_W(DIVI_ADDQ_W)) u_iteration(.dividend_2n(dividend_itr_cpd[2*DIVI_ADDQ_W:0]),
                    .divisor_2n( divisor_itr_cpd[2*DIVI_ADDQ_W+1:0]),
                    .dividend_2n_final(dividend_itr[2*DIVI_ADDQ_W:0]));
            end
            else begin
                if(i==(DIVI_ITR_CPD-1))begin
                    assign  dividend_itr_cpd[(i+1)*(2*DIVI_ADDQ_W+1)-1:i*(2*DIVI_ADDQ_W+1)] = (cnt == 0)?
                        dividend_itr_r[i*(2*DIVI_ADDQ_W+1)-1:(i-1)*(2*DIVI_ADDQ_W+1)]:
                        dividend_itr_r[(i+1)*(2*DIVI_ADDQ_W+1)-1:i*(2*DIVI_ADDQ_W+1)];
                    assign  divisor_itr_cpd[(i+1)*2*(DIVI_ADDQ_W+1)-1:i*2*(DIVI_ADDQ_W+1)] = (cnt == 0)?
                        divisor_itr_r[i*2*(DIVI_ADDQ_W+1)-1:(i-1)*2*(DIVI_ADDQ_W+1)]:
                        divisor_itr_r[(i+1)*2*(DIVI_ADDQ_W+1)-1:i*2*(DIVI_ADDQ_W+1)];
                    iteration #(.DIVI_ADDQ_W(DIVI_ADDQ_W)) u_iteration(
                        .dividend_2n(dividend_itr_cpd[(i+1)*(2*DIVI_ADDQ_W+1)-1:i*(2*DIVI_ADDQ_W+1)]),
                        .divisor_2n(divisor_itr_cpd[(i+1)*2*(DIVI_ADDQ_W+1)-1:i*2*(DIVI_ADDQ_W+1)]),
                        .dividend_2n_final(dividend_itr[(i+1)*(2*DIVI_ADDQ_W+1)-1:i*(2*DIVI_ADDQ_W+1)]),
                        .dividend_2n_sign(dividend_itr[DIVIDEND_W_ITR-1]));
                end
                else begin
                    assign  dividend_itr_cpd[(i+1)*(2*DIVI_ADDQ_W+1)-1:i*(2*DIVI_ADDQ_W+1)] = (cnt == 0)?
                        dividend_itr_r[i*(2*DIVI_ADDQ_W+1)-1:(i-1)*(2*DIVI_ADDQ_W+1)]:
                        dividend_itr_r[(i+1)*(2*DIVI_ADDQ_W+1)-1:i*(2*DIVI_ADDQ_W+1)];
                    assign  divisor_itr_cpd[(i+1)*2*(DIVI_ADDQ_W+1)-1:i*2*(DIVI_ADDQ_W+1)] = (cnt == 0)?
                        divisor_itr_r[i*2*(DIVI_ADDQ_W+1)-1:(i-1)*2*(DIVI_ADDQ_W+1)]:
                        divisor_itr_r[(i+1)*2*(DIVI_ADDQ_W+1)-1:i*2*(DIVI_ADDQ_W+1)];
                    iteration #(.DIVI_ADDQ_W(DIVI_ADDQ_W)) u_iteration(
                        .dividend_2n(dividend_itr_cpd[(i+1)*(2*DIVI_ADDQ_W+1)-1:i*(2*DIVI_ADDQ_W+1)]),
                        .divisor_2n(divisor_itr_cpd[(i+1)*2*(DIVI_ADDQ_W+1)-1:i*2*(DIVI_ADDQ_W+1)]),
                        .dividend_2n_final(dividend_itr[(i+1)*(2*DIVI_ADDQ_W+1)-1:i*(2*DIVI_ADDQ_W+1)]));
                end
            end
        end
    endgenerate

always@(*)
if(dividend_itr_r[DIVIDEND_W_ITR-1])
    begin
        
        remainder = dividend_itr_r[DIVIDEND_W_ITR-DIVI_ADDQ_W-2+DIVISOR_W:DIVIDEND_W_ITR-DIVI_ADDQ_W-2]+divisor_itr_r[DIVI_W_ITR-DIVI_ADDQ_W-2+DIVISOR_W:DIVI_W_ITR-DIVI_ADDQ_W-2]; //r=r+d
        
        quotient = dividend_itr_r[(DIVIDEND_W_ITR-DIVI_ADDQ_W-3):(DIVIDEND_W_ITR-2*DIVI_ADDQ_W-2)];
    end
    else begin
        
        remainder = dividend_itr_r[DIVIDEND_W_ITR-DIVI_ADDQ_W-2+DIVISOR_W:DIVIDEND_W_ITR-DIVI_ADDQ_W-2];
        
        quotient = dividend_itr_r[(DIVIDEND_W_ITR-DIVI_ADDQ_W-3):(DIVIDEND_W_ITR-2*DIVI_ADDQ_W-2)];
    end   //     quotient:quotient_temp.quotient_FRACT

assign quotient_temp = (QUOTIENT_FRACT_W==0)? quotient[DIVIDEND_W-1:0]:(quotient[(QUOTIENT_FRACT_W+DIVIDEND_W-1):QUOTIENT_FRACT_W]);


    assign remainder_temp = remainder[DIVISOR_W-1:0];


always@(posedge clk or negedge rst_n)
    if(!rst_n) begin
        
            remainder_r <= {DIVISOR_W {1'b0}}; 
            quotient_r <= {DIVIDEND_W{1'b0}};
    end
    else if(clk_en) begin
        
        quotient_r <= quotient_temp;
            remainder_r <= remainder_temp;

    end
    else begin
    end
endmodule

