
/*
PADDLE Modules
*/
module control_paddle_move
#(
	parameter 	RATE = 1,
				SCREEN_X = 'd640,
				SCREEN_Y = 'd480,
				X_SET = 'd10,
				Y_MAX = 'd480,
				X_PADDLE_SIZE = 8'd5,   // Paddle X dimension
				Y_PADDLE_SIZE = 7'd40,
				Y_MARGIN = 30
)
(
	input clk,
	input resetn,
	input enable,
	
	input[($clog2(Y_MAX)):0] x_pos,
	input[($clog2(Y_MAX)):0] y_pos,

	input up, down,
	output reg [1:0] y_dir
);
	// bit 1 is X direction, bit 2 is Y direction
	reg[1:0] current_state, next_state;
	wire topHit = (y_pos < (RATE + Y_MARGIN));
	wire botHit = (y_pos > Y_MAX - RATE - Y_PADDLE_SIZE);
	
		// state variable declarations
	localparam  S_STATIONARY   = 2'b00,
		    S_UP   	   = 2'b01,
		    S_DOWN   	   = 2'b10;

	
	always@(*)
	begin 
		if(!enable) begin
			// do nothing with states...
		end
		else begin

			// STATIONARY PADDLE 
			if(current_state == S_STATIONARY) begin
				if(up && !down && !topHit) next_state <= S_UP;
				else if(!up && down && !botHit) next_state <= S_DOWN;
				else next_state <= S_STATIONARY;
			end

			// VERTICAL DOWN BOUNDARY HANDLING
			else if(current_state == S_DOWN) begin
				if(botHit) next_state <= (up)?S_UP:S_STATIONARY;
				else  if(down && !up)next_state <= S_DOWN;
				else  if(!down && up)next_state <= S_UP;
				else next_state <= S_STATIONARY;
			end

			// VERTICAL UP BOUNDARY HANDLING
			else if(current_state == S_UP) begin
				if( topHit ) next_state <= (down)?S_DOWN:S_STATIONARY;
				else  if(down && !up) next_state <= S_DOWN;
				else  if(!down && up)next_state <= S_UP;
				else next_state <= S_STATIONARY;
			end		
			
			else next_state <= S_STATIONARY;

		end
	end // state_table for movement

	always@(*)
	begin
		y_dir <= current_state;
	end 

	always@(posedge clk)
	begin 
		if(!resetn) begin
			current_state = 2'b00;
		end
		else begin
			current_state = next_state;
		end
	end
endmodule

module paddle_physics
#(
parameter 	SCREEN_X = 10'd640,
		SCREEN_Y = 9'd480,
		X_SET = 'd10,
		X_SET2 = 'd625,
		Y_MAX = 'd480,
		X_PADDLE_SIZE = 8'd5,	
		Y_PADDLE_SIZE = 7'd40,  
		FRAME_RATE = 15,
		RATE = 1
)
(
	input clk,
	input resetn,
	input enable,

	// from rate divider
	input frameTick,
	input [($clog2(FRAME_RATE)):0] frameCount,

	// states
	input [1:0] y_dir,	//stationary = 0, up = 1, down = 2
	input [1:0] y_dir2,	
	 
	// paddle data
	output reg [($clog2(SCREEN_X)):0] paddle_x,
	output reg [($clog2(Y_MAX)):0] paddle_y,
	output reg [($clog2(SCREEN_X)):0] paddle_x2,
	output reg [($clog2(Y_MAX)):0] paddle_y2,

	output reg [($clog2(SCREEN_X)):0] old_paddle_x,
	output reg [($clog2(Y_MAX)):0] old_paddle_y,
	output reg [($clog2(SCREEN_X)):0] old_paddle_x2,
	output reg [($clog2(Y_MAX)):0] old_paddle_y2
);
	
	always@(posedge clk) begin 
  
		if(!resetn) begin	
			old_paddle_x <= paddle_x;
			old_paddle_y <= paddle_y;
			old_paddle_x2 <= paddle_x2;
			old_paddle_y2 <= paddle_y2;

			paddle_x <= X_SET;
			paddle_y <= SCREEN_Y/2;
			paddle_x2 <= X_SET2;
			paddle_y2 <= SCREEN_Y/2;

		end
		else begin
			if(!enable) begin
				// do nothing
			end
			else begin			
				if(frameTick) begin

					old_paddle_x <= paddle_x;
					old_paddle_y <= paddle_y;
					old_paddle_x2 <= paddle_x2;
					old_paddle_y2 <= paddle_y2;

					if(y_dir == 2'b01) paddle_y <= (paddle_y - RATE);
					else if(y_dir == 2'b10) paddle_y <= (paddle_y + RATE);

					if(y_dir2 == 2'b01) paddle_y2 <= (paddle_y2 - RATE);
					else if(y_dir2 == 2'b10) paddle_y2 <= (paddle_y2 + RATE);

				end
			end
		end
	end
	

endmodule

module paddle_render
#(
parameter 	SCREEN_X = 10'd640,
		SCREEN_Y = 9'd480,
		X_SET = 'd10,
		X_SET2 = 'd625,
		Y_MAX = 'd480,
		X_PADDLE_SIZE = 8'd5,	
		Y_PADDLE_SIZE = 7'd40,  
		FRAME_RATE = 15,
		RATE = 1
)
(
	input clk,
	input resetn,
	input enable,
	
	// from rate divider
	input frameTick,
	input [($clog2(FRAME_RATE)):0] frameCount,

	// need old and new ball positions
	input [($clog2(X_SET)):0] paddle_x,
	input [($clog2(Y_MAX)):0] paddle_y,
	input [($clog2(X_SET2)):0] paddle_x2,
	input [($clog2(Y_MAX)):0] paddle_y2,

	input [($clog2(X_SET)):0] old_paddle_x,
	input [($clog2(Y_MAX)):0] old_paddle_y,
	input [($clog2(X_SET2)):0] old_paddle_x2,
	input[($clog2(Y_MAX)):0] old_paddle_y2,
	
	// draw states and pulses
	input pulse_clear1, pulse_draw1, pulse_clear2, pulse_draw2,
	output done_clear1, done_draw1, done_clear2, done_draw2,
	
	// VGA outputs
	output reg [($clog2(SCREEN_X)):0] render_x,
	output reg [($clog2(SCREEN_Y)):0] render_y,
	output reg [2:0] col_out,
	output reg rendered
);

	// auxilary wires/signals
	// registers for clear box 
	wire [($clog2(X_SET)):0] pt_clear_x1;
	wire [($clog2(SCREEN_Y)):0] pt_clear_y1;
	wire [($clog2(X_SET2)):0] pt_clear_x2;
	wire [($clog2(SCREEN_Y)):0] pt_clear_y2;
		
	// registers for drawing new box
	wire [($clog2(X_SET)):0] pt_draw_x1;
	wire [($clog2(SCREEN_Y)):0] pt_draw_y1;
	wire [($clog2(X_SET2)):0] pt_draw_x2;
	wire [($clog2(SCREEN_Y)):0] pt_draw_y2;
	always@(posedge clk) begin   
		// Active Low Synchronous Reset
		if(!resetn) begin
			render_x <= 'd0;
			render_y <= 'd0;
			col_out <= 3'b0;
			rendered <= 0;
		end
		else begin
			if(!enable) begin
				// dont move the paddle
			end
			else begin
				if(pulse_clear1) begin
					// output the clearOld points
					render_x <= pt_clear_x1;
					render_y <= pt_clear_y1;
					col_out <= 3'b000;
					rendered <= 0;
				end
				else if(pulse_draw1) begin
					// output the drawNew points
					render_x <= pt_draw_x1;
					render_y <= pt_draw_y1;
					col_out <= 3'b111;
					rendered <= 0;
				end
				else if(pulse_clear2) begin
					// output the clearOld points
					render_x <= pt_clear_x2;
					render_y <= pt_clear_y2;
					col_out <= 3'b000;
					rendered <= 0;
				end
				else if(pulse_draw2) begin
					// output the drawNew points
					render_x <= pt_draw_x2;
					render_y <= pt_draw_y2;
					col_out <= 3'b111;
					rendered <= 0;
				end
				else begin
					// DONE RENDERING!!!
					render_x <= 'd0;
					render_y <= 'd0;
					col_out <= 3'b000;	
					rendered <= 1;
				end
			end
		end
	end

	// Delete old paddle 1
	drawBox_signal #(
		SCREEN_X,
		SCREEN_Y,
		X_SET,
		Y_MAX,
		X_PADDLE_SIZE,
		Y_PADDLE_SIZE
	) clearOld1 (
		clk,
		resetn,
		pulse_clear1,
		
		old_paddle_x,	
		old_paddle_y,	

		pt_clear_x1,
		pt_clear_y1,
		
		done_clear1
	);

	// use startDraw pulse to kickstart the drawNew cycle for p1
	drawBox_signal #(
		SCREEN_X,
		SCREEN_Y,
		X_SET,
		Y_MAX,
		X_PADDLE_SIZE,
		Y_PADDLE_SIZE
	) drawNew1 (
		clk,
		resetn,
		done_clear1||pulse_draw1,

		paddle_x,
		paddle_y,

		pt_draw_x1,
		pt_draw_y1,
		done_draw1
	);

	//repeat for paddle 2
	drawBox_signal #(
		SCREEN_X,
		SCREEN_Y,
		X_SET2,
		Y_MAX,
		X_PADDLE_SIZE,
		Y_PADDLE_SIZE
	) clearOld2 (
		clk,
		resetn,
		pulse_clear2,
		
		old_paddle_x2,	
		old_paddle_y2,	

		pt_clear_x2,
		pt_clear_y2,
		
		done_clear2
	);

	// use startDraw pulse to kickstart the drawNew cycle for p1
	drawBox_signal #(
		SCREEN_X,
		SCREEN_Y,
		X_SET2,
		Y_MAX,
		X_PADDLE_SIZE,
		Y_PADDLE_SIZE
	) drawNew2 (
		clk,
		resetn,
		done_clear2||pulse_draw2,

		paddle_x2,
		paddle_y2,

		pt_draw_x2,
		pt_draw_y2,
		done_draw2
	);

endmodule