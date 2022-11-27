`timescale 1ns/1ns

module mhp(
  //  sys
  input           i_clk,      i_rst, //i_rst is used as active-low enable
  //  ctrl
  input           i_send, //'1' for sending, '0' for receive
  output          o_done,
  input 				i_enable,
  //  user data
  input [15:0] i_dst,//not needed, destination will always be host?
  input [15:0] i_src,//not needed, source will always be board?
  input [15:0] i_size, //temporary zero payload size
  input [7:0] i_dtype,
  output [15:0] o_dst,
  output [15:0] o_src,
  output [15:0]	o_size,
  output [7:0]		o_dtype,
  //  eth
  input   [7:0]   i_rdata,
  input           i_rready,
  output          o_rreq,
  output  [7:0]   o_wdata,
  input           i_wready,
  output          o_wvalid 
);

//  fsm
reg   [1:0] state       = 0;
localparam  IDLE        = 0;
localparam  READ        = 1;
localparam  WRITE       = 2;


reg [2:0] mhpState = 0;
localparam DST_PHASE = 0;
localparam SRC_PHASE = 1;
localparam SIZE_PHASE = 2;
localparam DTYPE_PHASE = 3;
localparam PAYLOAD_PHASE = 4;
localparam SCS_PHASE = 5;

 

//  local regs
reg           done      = 0;
//  read regs
reg           r_req     = 0;
//  write regs
reg   [7:0]   w_data    = 0;
reg           w_valid   = 0;

reg isReadCmd = 0;

reg [15:0] payloadSize;
reg [15:0] destMhpAddr;
reg [15:0] srcMhpAddr;
reg [15:0] srsChkSum;
reg [7:0] mhpType;
reg dataDir;

reg[15:0] dst;
reg[15:0] src;
reg[15:0] size;
reg[7:0]	dtype;

reg doubleCycleCount = 0;

always @(posedge i_clk) begin
	//if (i_rst || !i_enable) begin
	if (i_rst) begin

		done    <= 0;
		w_data  <= 0;
		w_valid <= 0;
		r_req   <= 0; 
		state   <= IDLE;
		mhpState <= DST_PHASE;
		isReadCmd = 0;
		doubleCycleCount = 0;
	end
  /*
	else begin
		case (state)
			IDLE: begin
				w_data  <= 0;
				w_valid <= 0;
				done    <= 0;
				if (i_send) begin
				//sending
					if (i_wready) begin
						isReadCmd <= 0;
					//ethernet is ready to receive from us
						mhpState <= DST_PHASE;
					end
				end else begin
				//receiving
					if (i_rready) begin
						isReadCmd <= 1;
					// ethernet is ready to send to us
						r_req   <= 1;     // r_req set before read state, so we can expect valid data in READ state
						state   <= DST_PHASE;
					end
				end
			end
			
			DST_PHASE: begin
				if (isReadCmd && i_rready) begin
					addrCycleCount <= 1;
					if (addrCycleCount == 0) begin
						destMhpAddr[15:8] <= i_rdata;
					end else begin
						addrCycleCount <= 0;
						destMhpAddr[7:0] <= i_rdata;
						state <= SRC_PHASE;
					end
				end else if (!isReadCmd && i_wready) begin
					//TODO: temporary hack to get past MHP address
					addrCycleCount <= 1;
					w_valid <= 1;
					if (addrCycleCount == 0) begin
						w_data <= 8'hFF;
					end else begin
						addrCycleCount <= 0;
						w_data <= 8'hFF;
						state <= SRC_PHASE;
					end
				end
			end
			
			SRC_PHASE: begin
				if (isReadCmd && i_rready) begin
					addrCycleCount <= 1;
					if (addrCycleCount == 0) begin
						srcMhpAddr[15:8] <= i_rdata;
					end else begin
						addrCycleCount <= 0;
						srcMhpAddr[7:0] <= i_rdata;
						state <= SIZE_PHASE;
					end
				end else if (!isReadCmd && i_wready) begin
					//TODO: temporary hack to get past MHP address
					addrCycleCount <= 1;
					w_valid <= 1;
					if (addrCycleCount == 0) begin
						w_data <= 8'h00;
					end else begin
						addrCycleCount <= 0;
						w_data <= 8'h00;
						state <= SIZE_PHASE;
					end
				end
			end
			
			SIZE_PHASE: begin
				if (isReadCmd && i_rready) begin
					addrCycleCount <= 1;
					if (addrCycleCount == 0) begin
						payloadSize[15:8] <= i_rdata;
					end else begin
						addrCycleCount <= 0;
						payloadSize[7:0] <= i_rdata;
						state <= DTYPE_PHASE;
					end
				end else if (!isReadCmd && i_wready) begin
					//TODO: temporary 0 sized data to get past MHP address
					addrCycleCount <= 1;
					w_valid <= 1;
					if (addrCycleCount == 0) begin
						w_data <= 8'h00;
					end else begin
						addrCycleCount <= 0;
						w_data <= 8'h00;
						state <= DTYPE_PHASE;
					end
				end
			end
			
			DTYPE_PHASE: begin
				if (isReadCmd && i_rready) begin
						mhpType <= i_rdata[6:0];
						dataDir <= i_rdata[7];
						if (payloadSize == 16'h0000)
							state <= SCS_PHASE;
						else
							state <= PAYLOAD_PHASE;
				end else if (!isReadCmd && i_wready) begin
						//TODO: temporary hack for address request mhptype
						w_valid <= 1;
						w_data <= 8'h83;
						state <= SCS_PHASE;
					end
				end
			
			
			PAYLOAD_PHASE: begin
				state <= SCS_PHASE;
			end
			
			SCS_PHASE: begin
				if (isReadCmd && i_rready) begin
					addrCycleCount <= 1;
					if (addrCycleCount == 0) begin
						srsChkSum[15:8] <= i_rdata;
					end else begin
						addrCycleCount <= 0;
						srsChkSum[7:0] <= i_rdata;
						state <= IDLE;
						done <= 1;
					end
				end else if (!isReadCmd && i_wready) begin
					//TODO: temporary 0 sized data to get past MHP address
					addrCycleCount <= 1;
					w_valid <= 1;
					if (addrCycleCount == 0) begin
						w_data <= 8'h00;
					end else begin
						addrCycleCount <= 0;
						w_data <= 8'h00;
						state <= IDLE;
						done <= 1;
					end
				end
			end
		endcase
	end
  */
  else begin
    case (state)
      IDLE: begin
        w_data  <= 0;
        w_valid <= 0;
        done    <= 0;
		  doubleCycleCount <= 0;
        if (i_rready) begin // received frame's payload ready
          r_req   <= 1;     // r_req set before read state, so we can expect valid data in READ state
          state   <= READ;
        end else
          r_req   <= 0;
      end
      READ: begin
        if (i_rready)
				case (mhpState)
					DST_PHASE: begin
					  doubleCycleCount <= 1;
					  if (doubleCycleCount == 0)
							destMhpAddr[15:8] <= i_rdata;
					  else begin
							doubleCycleCount <= 0;
							destMhpAddr[7:0] <= i_rdata;
							mhpState <= SRC_PHASE;
						end
					end
					
					SRC_PHASE: begin
						doubleCycleCount <= 1;
					  if (doubleCycleCount == 0)
							srcMhpAddr[15:8] <= i_rdata;
					  else begin
							doubleCycleCount <= 0;
							srcMhpAddr[7:0] <= i_rdata;
							mhpState <= SIZE_PHASE;
						end
					end
					
					SIZE_PHASE: begin
						doubleCycleCount <= 1;
						if (doubleCycleCount == 0) begin
							payloadSize[15:8] <= i_rdata;
						end else begin
							doubleCycleCount <= 0;
							payloadSize[7:0] <= i_rdata;
							mhpState <= DTYPE_PHASE;
						end
					end
					
					DTYPE_PHASE: begin
						mhpType <= i_rdata;
						if (payloadSize == 16'h0000)
							mhpState <= SCS_PHASE;
						else
							mhpState <= PAYLOAD_PHASE;
					end
					PAYLOAD_PHASE: begin
						mhpState <= SCS_PHASE;
					end
					
					SCS_PHASE: begin
						doubleCycleCount <= 1;
						if (doubleCycleCount == 0) begin
							srsChkSum[15:8] <= i_rdata;
						end else begin
							doubleCycleCount <= 0;
							srsChkSum[7:0] <= i_rdata;
							mhpState <= DST_PHASE;
						end
					end
				endcase
        else begin
          r_req   <= 0;
          done    <= 1;
          state   <= WRITE;
        end
      end
      WRITE: begin    //  write data
        if (i_wready) begin
          w_valid <= 1;
          state   <=  IDLE;
        end
      end
    endcase
  end
  
end

assign o_dst = destMhpAddr; //dst,
assign o_src = srcMhpAddr;//src,
assign o_size = payloadSize;//size,
assign o_dtype = mhpType;//dtype,

assign    o_done   = done;
assign    o_rreq   = r_req;
assign    o_wdata  = w_data;
assign    o_wvalid = w_valid;

endmodule
