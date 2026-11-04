//DVP����
module cmos_capture #(
    parameter DATA_WIDTH = 16,
              DELAY = DATA_WIDTH/8
)(
    input                 rst_n            ,  //��λ�ź�    
    //����ͷ�ӿ�                           
    input                 cam_pclk         ,  //cmos ��������ʱ��
    input                 cam_vsync        ,  //cmos ��ͬ���ź�
    input                 cam_href         ,  //cmos ��ͬ���ź�
    input  [7:0]          cam_data         ,                      
    //�û��ӿ�                              
    output                      cmos_frame_vsync ,  //֡��Ч�ź�    
    output                      cmos_frame_href  ,  //����Ч�ź�
    output                      cmos_frame_valid ,  //8bitת16bit������Чʹ���ź�
    output  [DATA_WIDTH-1 : 0]  cmos_frame_data     //��Ч����        
);


    wire            pos_vsync        ;
    reg    [DATA_WIDTH-1 : 0] cmos_data_t;
    reg [DATA_WIDTH-1-8 : 0] cam_data_temp;
    reg [1 : 0] temp_cnt;

    //�Ĵ���ȫ��������ɺ��ȵȴ�10֡����
    //���Ĵ���������Ч���ٿ�ʼ�ɼ�ͼ��
    parameter  WAIT_FRAME = 4'd10    ;            //�Ĵ��������ȶ��ȴ���֡���� 
    
    //��֡�����м���
    reg    [3:0]    cmos_ps_cnt      ;            //�ȴ�֡���ȶ�������
    always @(posedge cam_pclk or negedge rst_n) begin
        if(!rst_n)
            cmos_ps_cnt <= 4'd0;
        else if(pos_vsync && (cmos_ps_cnt < WAIT_FRAME))
            cmos_ps_cnt <= cmos_ps_cnt + 4'd1;
    end

    //֡��Ч��־
    reg             frame_val_flag   ;            //֡��Ч�ı�־ 
    always @(posedge cam_pclk or negedge rst_n) begin
        if(!rst_n)
            frame_val_flag <= 1'b0;
        else if((cmos_ps_cnt == WAIT_FRAME) && pos_vsync)
            frame_val_flag <= 1'b1;
        else;    
    end 

    
    //*****************************************************
    //**                    main code
    //*****************************************************
    /////////////////ƴ���ӳ�///////////
    reg [DELAY-1 : 0] cam_vsync_d, cam_href_d;
    always @(posedge cam_pclk or negedge rst_n) begin
        if(!rst_n) begin
            cam_vsync_d <= 1'b0;
            cam_href_d  <= 1'b0;
        end
        else begin
            cam_vsync_d <= {cam_vsync_d[DELAY-2 : 0], cam_vsync}; 
            cam_href_d  <= {cam_href_d[DELAY-2 : 0] , cam_href}; 
        end
    end

    reg cam_href_up;
    always @(posedge cam_pclk or negedge rst_n) begin
        if(!rst_n) begin
            cam_href_up <= 1'b0;
        end
        else begin
            cam_href_up <= cam_href_d[DELAY-1];
        end
    end








    //8λ����ת16λRGB565����        
    always @(posedge cam_pclk or negedge rst_n) begin
        if(!rst_n) begin
            cmos_data_t <= {DATA_WIDTH{1'b0}};
        end
        else if(cam_href && (temp_cnt == DATA_WIDTH/8 - 1)) begin
            cmos_data_t <= {cam_data_temp[DATA_WIDTH-1-8 : 0], cam_data};
        end
    end

    always @(posedge cam_pclk or negedge rst_n) begin
        if(!rst_n) begin
            cam_data_temp <= {DATA_WIDTH-8{1'b0}};
        end
        else if(cam_href) begin
            cam_data_temp <= (cam_data_temp << 8) | cam_data;
        end
        else begin
            cam_data_temp <= {DATA_WIDTH-8{1'b0}};
        end
    end

    always @(posedge cam_pclk or negedge rst_n) begin
        if(!rst_n) begin
            temp_cnt <= 2'd0;
        end      
        else if(cam_href) begin
            if(temp_cnt == DATA_WIDTH/8 - 1) begin
                temp_cnt <= 2'd0;
            end
            else begin
                temp_cnt <= temp_cnt + 1'b1;
            end
        end
        else begin
            temp_cnt <= 2'd0;
        end
    end


    reg valid_flag;
    //�������������Ч�ź�(cmos_frame_valid)
    always @(posedge cam_pclk or negedge rst_n) begin
        if(!rst_n) begin
            valid_flag <= 1'b0;
        end
        else if(cam_href && (temp_cnt == DATA_WIDTH/8 - 1)) begin
            valid_flag <= 1'b1;
        end	
        else begin
            valid_flag <= 1'b0;
        end
    end 


    //�����볡ͬ���źŵ�������           
    assign pos_vsync = (~cam_vsync_d[DELAY-1]) & cam_vsync_d[DELAY-1-1]; 

    //���֡��Ч�ź�
    assign  cmos_frame_vsync = frame_val_flag  ?  cam_vsync_d[DELAY-1]  :  1'b0; 

    //�������Ч�ź�
    // assign  cmos_frame_href  = frame_val_flag  ?  cam_href_d[DELAY-1] & (~cam_href_up) :  1'b0; 
    assign  cmos_frame_href  = frame_val_flag  ?  cam_href_d[DELAY-1] :  1'b0; 


    //�������ʹ����Ч�ź�
    assign  cmos_frame_valid = frame_val_flag  ?  valid_flag  :  1'b0; 

    //�������
    assign  cmos_frame_data  = frame_val_flag  ?  cmos_data_t  :  1'b0; 




endmodule
