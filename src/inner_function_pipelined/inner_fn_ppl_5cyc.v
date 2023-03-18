module inner_fn_ppl_5cyc(
	aclr,
	clk_en,
	clk,
	dataa,
	result);
	
	parameter [31:0] flt_128 = 32'h43000000; 				// 128.0
	parameter [31:0] flt_recip_128 = 32'h3c000000;		// 1.0/128.0
	parameter [31:0] flt_recip_2 = 32'h3f000000;			// 0.5
	parameter fp_mult_latency = 2;
	parameter fp_add_latency = 3;
	parameter cordic_latency = 5;
	

   	input		aclr;
	input		clk_en;
	input		clk;
	input		[31:0]  dataa; // this is the floating point input
	output	[31:0]  result;
	
	// 0.5 * x
	// 11 cycles
	wire [31:0] x_half;
	fp_mult_2cyc div_x_2(
		.areset(aclr),
		.en(clk_en),
		.clk(clk),
		.a(dataa),
		.b(flt_recip_2),
		.q(x_half)
	);
	parameter x_half_buffer_len = fp_add_latency + fp_mult_latency + cordic_latency;
	reg [31:0] x_half_buffer [x_half_buffer_len-1:0];
	
	
	// x^2
	// 11 cycles
	wire [31:0] x_squared;
	fp_mult_2cyc x_sq_mult(
		.areset(aclr),
		.en(clk_en),
		.clk(clk),
		.a(dataa),
		.b(dataa),
		.q(x_squared)
	);
	parameter x_sq_buffer_len = fp_add_latency + cordic_latency;
	reg [31:0] x_sq_buffer [x_sq_buffer_len-1:0];
	
	
	// x - 128
	// 14 cycles
	wire [31:0] x_sub_128;
	fp_addsub_3cyc sub_x_128(
		.areset(aclr),
		.en(clk_en),
		.clk(clk),
		.a(dataa),
		.b(flt_128), 
		.q(x_sub_128),
		.opSel(0)
	);
	
	
	// (x-128)/128
	// 11 cycles
	wire [31:0] x_div_128;
	fp_mult_2cyc div_x_128(
		.areset(aclr),
		.en(clk_en),
		.clk(clk),
		.a(x_sub_128),
		.b(flt_recip_128),
		.q(x_div_128)
	);
	
	
	// cos((x-128)/128)
	// 17 cycles
	wire [31:0] cordic_out;
	cordic_ppl_5cyc_ub unit(
		.aclr(aclr),
		.clk_en(clk_en),
		.clock(clk),
		.dataa(x_div_128),
		.result(cordic_out)
	);
	//	assign cordic_out = 32'h3f000000;
	
	
	// x^2 * cos((x-128)/128)
	// 11 cycles
	wire [31:0] term_mult;
	fp_mult_2cyc mult_term(
		.areset(aclr),
		.en(clk_en),
		.clk(clk),
		.a(cordic_out),
		.b(x_sq_buffer[x_sq_buffer_len-1]),
		.q(term_mult)
	);
	
	
	// 0.5*x + x^2 * cos((x-128)/128)
	// 14 cycles
	fp_addsub_3cyc add_term(
		.areset(aclr),
		.en(clk_en),
		.clk(clk),
		.a(term_mult),
		.b(x_half_buffer[x_half_buffer_len-1]), 
		.q(result),
		.opSel(1)
	);

	
	integer i;
	
	always @(posedge clk) begin
		if (aclr) begin
		
			for (i = 0; i < x_half_buffer_len; i = i + 1) begin
				x_half_buffer[i] <= 32'd0;
			end
			
			for (i = 0; i < x_sq_buffer_len; i = i + 1) begin
				x_sq_buffer[i] <= 32'd0;
			end
			
		end
		else if (clk_en) begin
		
			x_half_buffer[0] <= x_half;
			for (i = 1; i < x_half_buffer_len; i = i + 1) begin
				x_half_buffer[i] <= x_half_buffer[i-1];
			end
			
			x_sq_buffer[0] <= x_squared;
			for (i = 1; i < x_sq_buffer_len; i = i + 1) begin
				x_sq_buffer[i] <= x_sq_buffer[i-1];
			end
			
		end
	end

endmodule