`timescale 1ns/1ns

module control(
  //  sys
  input           i_clk, i_rst,
  output          o_link,
  //  eth
  input   [7:0]   i_eth_rdata,
  input           i_eth_rready,
  output          o_eth_rreq,
  output  [7:0]   o_eth_wdata,
  input           i_eth_wready,
  output          o_eth_wvalid,
  //  uart rx
  input   [7:0]   i_uart_rdata,
  input           i_uart_rready,
  output          o_uart_rreq,
  //  uart tx
  output  [7:0]   o_uart_wdata,
  input           i_uart_wready,
  output          o_uart_wvalid
);


reg[7:0] uartTxByte;
reg uartTxRdy;
reg taskmanEn;
reg[25:0] uartDelayCounter;
reg[3:0] uartPrintCycle;

wire[15:0] desty;
wire[15:0] saucy;
wire addrGranted;

always@(posedge i_clk) begin
	if (!i_rst) begin
		uartDelayCounter <= uartDelayCounter + 1;
		if (uartDelayCounter == 25'hFFFF) begin
			taskmanEn <= 1;
		end
		if (uartDelayCounter == 0) begin
			taskmanEn <= 0;
		end
		
		if (addrGranted) begin
			uartTxRdy <= 1;
		end
		
		if (uartTxRdy == 1) begin
			uartPrintCycle <= uartPrintCycle + 1;
			case (uartPrintCycle)
				0: begin
					uartTxByte <= 8'h0A; //newline?
				end
				1: begin
					uartTxByte <= 8'h24; //dollar sign
				end
				2: begin
					uartTxByte <= desty[15:8];
				end
				3: begin
					uartTxByte <= desty[7:0];
				end
				4: begin
					uartTxByte <= saucy[15:8];
				end
				5: begin
					uartTxByte <= saucy[7:0];
				end
				6: begin
					uartTxByte <= 8'h24; //dollar sign
				end
				7: begin
					uartTxByte <= 8'h0A; //newline?
					uartTxRdy <= 0;
				end
				default: begin
					uartPrintCycle <= 0;
					uartTxRdy <= 0;
				end
			endcase
		end
	end
end



task_manager task_manager(
  //  sys
  .i_clk    (i_clk),
  .i_rst    (i_rst),
  .o_link   (o_link),
  //data
  .i_taskStart (taskmanEn),
  .addrGrantStrobe (addrGranted),
  .o_destAddr (desty),
  .o_srcAddr (saucy),
  //  eth
  .i_rdata  (i_eth_rdata),
  .i_rready (i_eth_rready),
  .o_rreq   (o_eth_rreq),
  .o_wdata  (o_eth_wdata),
  .i_wready (i_eth_wready),
  .o_wvalid (o_eth_wvalid)
);

debug_port debug_port(
  //  sys
  .i_clk    (i_clk),
  .i_rst    (i_rst),
  //debug signals
  .debugToPC (uartTxByte),
  .debugToPCRdy (uartTxRdy),
  
  //  uart rx
  .i_rdata  (i_uart_rdata),
  .i_rready (i_uart_rready),
  .o_rreq   (o_uart_rreq),
  //  uart tx
  .i_wready (1),
  .o_wdata  (o_uart_wdata),
  .o_wvalid (o_uart_wvalid)
);

endmodule
