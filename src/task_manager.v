module task_manager(
  //  sys
  input           i_clk,      i_rst,
  output          o_link,
  //data
  input 				i_taskStart,
  input 	 [15:0]	i_taskNbr,
  output	 reg[15:0]  o_destAddr,
  output	reg[15:0]  o_srcAddr,
  output reg addrGrantStrobe,
  //  eth
  input   [7:0]   i_rdata,
  input           i_rready,
  output          o_rreq,
  output  [7:0]   o_wdata,
  input           i_wready,
  output          o_wvalid
);

//  fsm - add task control here
reg [1:0]     state     = 0;
localparam    IDLE      = 0;
localparam    CONNECTED = 1;
localparam    LINKED    = 2;

wire          done;
reg           link      = 0, send     = 0;
reg mhpEnable;
reg[15:0] currentTask;

reg[6:0] mhpType;
reg[15:0] dstAddr;
reg[15:0] srcAddr;
reg dataDir;

always @(posedge i_clk) begin
	if (i_rst) begin
		addrGrantStrobe <= 0;
		mhpEnable <= 0;
		link  <= 0;
		send  <= 0;
		currentTask <= 0;
		state <= IDLE;
	end else begin
		case (state)
      IDLE: begin
        link <= 0;
        if (done) begin
          send  <=  1;
          state <= CONNECTED;
        end
      end
      CONNECTED: begin
        if (done)
          state <= LINKED;
        else
          send  <=  0;
      end
      LINKED: begin
        if (done) begin
          link  <= 0;
          send  <= 1;
          state <= CONNECTED;
        end else
          link <= 0; // change to 1 to enable MHP protocol ethertype usage
      end
    endcase
	end
  
  
  /*
  else begin
    case (state)
      IDLE: begin
        link <= 0;
        if (done) begin
          send  <=  1;
          state <= CONNECTED;
        end
      end
      CONNECTED: begin
        if (done)
          state <= LINKED;
        else
          send  <=  0;
      end
      LINKED: begin
        if (done) begin
          link  <= 0;
          send  <= 1;
          state <= CONNECTED;
        end else
          link <= 0; // change to 1 to enable MHP protocol ethertype usage
      end
    endcase
  end
  */
end


//decode from "READY" task number to appropriate MHP opcode
always@(*) begin
	case (currentTask[7:0])
		8'h10: begin
			mhpType = 7'h03;
		end
		8'h20: begin
			mhpType = 7'h01;
		end
		8'h30: begin
			mhpType = 7'h05;
		end
		default: begin
			mhpType = 7'h00;
		end
	endcase
end


wire[6:0] o_mhpType = mhpType;

wire[6:0] i_dType;
wire[15:0] i_dstAddr;
wire[15:0] i_srcAddr;

mhp protocol(
  //  sys
  .i_clk    (i_clk),
  .i_rst    (i_rst),
  //  ctrl
  .i_send   (send),
  .i_enable	(mhpEnable),
  .o_done   (done),
  //  user data
  .i_dst  ({16'hFFFF}),//not needed, destination will always be host?
  .i_src  ({16'h0000}),//not needed, source will always be board?
  .i_size	({16'h0000}), //temporary zero payload size
  .i_dtype	({1'b1, o_mhpType}),
  .o_dst	 (i_dstAddr),
  .o_src	 (i_srcAddr),
  .o_size (i_size),
  .o_dtype(i_dType),
  //  eth
  .i_rdata  (i_rdata),
  .i_rready (i_rready),
  .o_rreq   (o_rreq),
  .o_wdata  (o_wdata),
  .i_wready (i_wready),
  .o_wvalid (o_wvalid)
);

assign  o_link  = link;

endmodule