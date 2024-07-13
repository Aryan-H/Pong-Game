/*
Ball Modules
*/

module control_ball_movement
#(
	parameter 	RATE = 1,
				SCREEN_X = 'd640,
				SCREEN_Y = 'd480,
				
				X_MAX = 'd640,
				Y_MIN = 'd20,
				Y_MAX = 'd480,

				X_BOXSIZE = 8'd4,	// Box X dimension
				Y_BOXSIZE = 7'd4,  	// Box Y dimension
				MAX_RATE = 'd15,

				PADDLE_X = 'd4,
				PADDLE_Y = 'd15,
				PADDLE_OFFSET = 'd2,
				PADDLE_MAX_Y = 'd480
)
(
	input clk,
	input resetn,
	input enable,
	input blackScreen,
	input frameTick,

	input[($clog2(X_MAX)):0] x_pos,
	input[($clog2(Y_MAX)):0] y_pos,
	input[($clog2(MAX_RATE)):0]	actual_rate,

	input[($clog2(PADDLE_MAX_Y)):0] left_paddle_pos_y,
	input[($clog2(PADDLE_MAX_Y)):0] right_paddle_pos_y,

	output reg x_dir,
	output reg y_dir,
	
	output reg lhs_scored,
	output reg rhs_scored,
	output reg boundary_contact
);
	// bit 1 is X direction, bit 2 is Y direction
	reg[1:0] current_move_state, next_move_state;

	// score registers (0 = nothing, 1 = left scored, 2 = right scored, 4 = vert bound hit)
	reg[1:0] current_score_state, next_score_state;

	// movement state variable declarations
	localparam  S_LEFT   = 1'b0,
				S_RIGHT   	= 1'b1,
				S_UP        = 1'b0,
				S_DOWN   	= 1'b1;

	localparam 	X_MIN = PADDLE_X + PADDLE_OFFSET;
	
	localparam 	S_PLAY = 2'd0,
				S_LEFT_SCORED = 2'd1,
				S_RIGHT_SCORED = 2'd2,
				S_BOUND_HIT = 2'd3;

	wire leftHit, rightHit;
	wire scored = lhs_scored||rhs_scored; // used for draw state table
	// movement state table
	always@(*)
	begin 
		if(!enable) begin
			// do nothing with states...
		end
		else begin
			//NOTE REGARDING COORDINATE SYSTEM:
			// RIGHTWARD -> LARGER X VALUE
			// DOWNWARD -> LARGER Y VALUE
			// therefore, bottom bound is when y is at max value! (vice versa for top bound)
			// set next state based on whether the ball will hit the wall or not
			/*
			*** IMPLEMENT PADDLE WIDTH INTO LEFT AND RIGHT BOUNDS (X_MAX )
			CHECK BOT X/TOP X coordinate depending on which bound we are approaching
			based on the coordinate of the paddle, and its width, check if we will hit the paddle
			if it does, fire the score signal, based on which side it went in
			*/

			// NOTE: DO VERT CHECKS FIRST SO SCORE STATES ARE NOT OVERWRITTEN

			// VERTICAL BOUNDARY HANDLING
			if(current_move_state[0] == S_DOWN) begin
				// going down
				if(y_pos > Y_MAX - actual_rate) begin
					// if we go more down, we will hit the wall
					next_move_state[0] <= S_UP;
					next_score_state <= S_BOUND_HIT;
				end
				else begin
					next_move_state[0] <= S_DOWN;
					// DO NOT OVERWRITE IF A SCORE HAS OCCURED!
					next_score_state <= S_PLAY;
				end
			end	
			else begin
				// must be going upward
				if(y_pos < Y_MIN + actual_rate) begin
					// if we go more down, we will hit the wall
					next_move_state[0] <= S_DOWN;
					next_score_state <= S_BOUND_HIT;
				end
				else begin
					next_move_state[0] <= S_UP;
					// DO NOT OVERWRITE IF A SCORE HAS OCCURED!
					next_score_state <= S_PLAY;
				end
			end
			
			// HORIZONTAL BOUNDARY HANDLING
			// check if a score occured, and who did it
			if(current_score_state == S_LEFT_SCORED) begin
				// left player got a goal, move to right at new round
				next_move_state[1] <= S_LEFT;
				// if we are still in the net, keep score signal on
				next_score_state <= (x_pos > X_MAX - X_BOXSIZE - actual_rate)?S_LEFT_SCORED:S_PLAY;
			end
			else if(current_score_state == S_RIGHT_SCORED) begin
				// right player got a goal, move to left at new round
				next_move_state[1] <= S_RIGHT;
				// if we are still in the net, keep score signal on
				next_score_state <= (x_pos < X_MIN)?S_RIGHT_SCORED:S_PLAY;
			end
			// no score occured, do normal checks
			else begin
				if(current_move_state[1] == S_LEFT) begin
					// going left
					if(x_pos < X_MIN) begin
						// if we go more left, we will hit the wall. DO PADDLE CHECK***
						next_move_state[1] <= S_RIGHT;
						if(leftHit) begin
							// hit paddle
							next_score_state <= S_BOUND_HIT;
						end
						else begin
							// no hit, right player scored
							next_score_state <= S_RIGHT_SCORED;
						end
					end
					else begin 
						next_move_state[1] <= S_LEFT;
						// if no event occurs, keep doing no event. otherwise, keep the event
					end
				end
				else begin
					// must be going right
					if(x_pos > X_MAX - X_BOXSIZE -actual_rate) begin
						// if we go more right, we will hit the wall. DO PADDLE CHECK***
						next_move_state[1] <= S_LEFT;
						if(rightHit) begin
							// paddle hit
							next_score_state <= S_BOUND_HIT;
						end
						else begin
							// no hit, left player scored
							next_score_state <= S_LEFT_SCORED;
						end
					end
					// no bound needed
					else begin
						next_move_state[1] <= S_RIGHT;
						// if no event occurs, keep doing no event. otherwise, keep the event
					end 
				end
			end
		end
	end // end of movement state table

	
	// Output logic aka all of our datapath control signals
	always@(*)
	begin
		//
		x_dir <= current_move_state[1];
		y_dir <= current_move_state[0];	

		// score stuff
		lhs_scored <= 0;
		rhs_scored <= 0;
		boundary_contact <= 0;
		case(current_score_state)
			S_PLAY: begin
				// no change
			end

			S_LEFT_SCORED: begin
				lhs_scored <= 1;
			end

			S_RIGHT_SCORED: begin
				rhs_scored <= 1;
			end

			S_BOUND_HIT: begin
				boundary_contact <= 1;
			end
		endcase
	end 


	// set state registers to next state
	always@(posedge clk)
	begin 
		if(!resetn) begin
			// reset to be unpaused, moving down right
			current_move_state <= 2'b11;
			current_score_state <= S_PLAY;
		end
		else begin
			current_move_state <= next_move_state;
			current_score_state <= next_score_state;
		end
	end


	// instantiate hitbox modules
	hitDetect 	#(Y_BOXSIZE, Y_MAX,
				PADDLE_Y, PADDLE_MAX_Y)
		left_bound
				(y_pos, left_paddle_pos_y, leftHit);

	hitDetect 	#(Y_BOXSIZE, Y_MAX,
				PADDLE_Y, PADDLE_MAX_Y)
		right_bound
				(y_pos, right_paddle_pos_y, rightHit);
endmodule

module hitDetect
#(
	parameter 	Y_BOXSIZE = 7'd4,   // Box Y dimension
				Y_MAX = 9'd480,
				PADDLE_Y = 'd15, 	// Paddle Y dimension
				PADDLE_MAX_Y = 'd480
)
(
	input [($clog2(Y_MAX)):0] ball_y,
	input [($clog2(PADDLE_MAX_Y)):0] paddle_y,
	output contact
);
	wire topCheck = (ball_y < (paddle_y + PADDLE_Y)); // top of ball is above bottom of paddle
	wire botCheck = ((ball_y) > paddle_y - Y_BOXSIZE); // bottom of ball is below top of paddle
	assign contact = (topCheck && botCheck);
endmodule

module ball_physics
#(
	parameter 	SCREEN_X = 10'd640,
				SCREEN_Y = 9'd480,
				X_MAX = 10'd640,
				Y_MIN = 20,
				Y_MAX = 9'd480,
				X_BOXSIZE = 8'd4,	// Box X dimension
				Y_BOXSIZE = 7'd4,   // Box Y dimension
				FRAME_RATE = 15,
				RATE = 1,
				MAX_RATE = 15,
				TIME_TILL_ACCEL = 'd2,
				PADDLE_WIDTH = 'd4,
				PADDLE_HEIGHT = 'd15,
				PADDLE_OFFSET = 'd2	
)
(
	input clk,
	input resetn,
	input enable,
	
	// from rate divider
	input frameTick,
	input [($clog2(FRAME_RATE)):0] frameCount,

	// move states
	input x_dir, 	//left = 0, right = 1
	input y_dir,	//up = 0, down = 1
	
	input blackScreen_pulse,

	// ball data
	output reg [($clog2(X_MAX)):0] ball_x,
	output reg [($clog2(Y_MAX)):0] ball_y,

	output reg [($clog2(X_MAX)):0] old_x,
	output reg [($clog2(Y_MAX)):0] old_y,

	output reg [($clog2(MAX_RATE)):0] actual_rate
);
	localparam 	resetPos_X = SCREEN_X/2,
				resetPos_Y = SCREEN_Y/2;

	// use this secondCounter to increase rate
	// after x seconds, increase rate!
	reg[($clog2(TIME_TILL_ACCEL)):0] secondCounter;

	// actually draw the ball on the updated position
	always@(posedge clk) begin   
		// Active Low Synchronous Reset
		if(!resetn) begin
			old_x <= ball_x;
			old_y <= ball_y;
			ball_x <= resetPos_X;
			ball_y <= resetPos_Y;
		end
		else begin
			if(!enable) begin
				// dont move the ball
			end
			else begin
				// actually move the ball on a frame tick!
				if(frameTick) begin
					old_x <= ball_x;
					old_y <= ball_y;
						
					// otherwise, just update the ball!
					ball_x <= (x_dir)?(ball_x + actual_rate):(ball_x - actual_rate);
					ball_y <= (y_dir)?(ball_y + actual_rate):(ball_y - actual_rate);
				end
				// after moving the ball, if blackScreen pulse was sent (regardless of whether it was a frame or not), reset
				if(blackScreen_pulse) begin
					// reset ball position upon black screening
					ball_x <= resetPos_X;
					ball_y <= resetPos_Y;
				end
			end
		end
	end

	// increase speed of the ball
	always@(posedge clk) begin // must be on clock edge... figure out a way such that it only occurs when it has JUST become frameCount == frame_rate, rather than occuring every clock tick whilst frameCount == frame_rate
		if(!resetn) begin
			secondCounter <= 0;
			actual_rate <= RATE;
		end
		else begin
			if(blackScreen_pulse) begin
				// reset upon screen clear as well!
				actual_rate <= RATE;
				secondCounter <= 0;
			end
			if(secondCounter == TIME_TILL_ACCEL && frameTick) begin
				// if the specified time till acceleration has passed, increase the rate of movement!
				actual_rate <= (actual_rate < MAX_RATE)?actual_rate + 1:MAX_RATE;
				secondCounter <= 0;
			end
			else if(frameCount == FRAME_RATE && frameTick) begin
				// just increase the second counter
				secondCounter <= secondCounter + 1;
			end
		end
	end
endmodule

module ball_render
#(
	parameter 	SCREEN_X = 10'd640,
				SCREEN_Y = 9'd480,

				X_MAX = 10'd640,
				Y_MAX = 9'd480,

				X_BOXSIZE = 8'd4,	// Box X dimension
				Y_BOXSIZE = 7'd4,   // Box Y dimension

				FRAME_RATE = 15,
				RATE = 1,
				MAX_RATE = 15
)
(
	input clk,
	input resetn,
	input [2:0] color,
	input enable,
	
	// from rate divider
	input frameTick,
	input [($clog2(FRAME_RATE)):0] frameCount,

	// need old and new ball positions
	input [($clog2(X_MAX)):0] ball_x,
	input [($clog2(Y_MAX)):0] ball_y,

	input [($clog2(X_MAX)):0] old_x,
	input [($clog2(Y_MAX)):0] old_y,
	
	// draw states and pulses
	input clearOld_pulse,
	input drawNew_pulse,
	input blackScreen_pulse,

	output done_clearOld,
	output done_drawNew,
	output done_blackScreen,
	
	// VGA outputs
	output reg [($clog2(SCREEN_X)):0] render_x,
	output reg [($clog2(SCREEN_Y)):0] render_y,
	output reg [2:0] col_out,
	output reg rendered
);

	// auxilary wires/signals
	// registers for clear box 
	wire [($clog2(SCREEN_X)):0] pt_clear_x;
	wire [($clog2(SCREEN_Y)):0] pt_clear_y;
		
	// registers for drawing new box
	wire [($clog2(SCREEN_X)):0] pt_draw_x;
	wire [($clog2(SCREEN_Y)):0] pt_draw_y;

	// registers for cleaning the screen
	wire [($clog2(SCREEN_X)):0] blk_x;
	wire [($clog2(SCREEN_Y)):0] blk_y;
	wire [2:0] back_col;
	wire[16:0] address = (blk_x + (320 * blk_y));

	// change name based on the ROM image you want...
	stars_1_ROM backgroundA(
		address,
		clk,
		back_col
	);

	always@(posedge clk) begin   
		// Active Low Synchronous Reset
		if(!resetn) begin
			render_x <= blk_x;
			render_y <= blk_y;
			col_out <= 3'b000;
			
			rendered <= 0;
			// clear and drawing counters reset in their modules
		end
		else begin
			if(!enable) begin
				// dont move the ball
			end
			else begin
				// handle drawing the ball
				// on the start of a frame, draw it, and dont stop until it is done
				
				// need to determine which points are outputted to be rendered!
				if(clearOld_pulse) begin
					// output the clearOld points
					render_x <= pt_clear_x;
					render_y <= pt_clear_y;
//					col_out <= 3'b000;
					rendered <= 0;
				end
				else if(drawNew_pulse) begin
					// output the drawNew points
					render_x <= pt_draw_x;
					render_y <= pt_draw_y;
					col_out <= color;
					rendered <= 0;
				end
				else if(blackScreen_pulse) begin
					// has to be outputting the clean screen points
					render_x <= blk_x;
					render_y <= blk_y;
					col_out <= back_col;
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

	// instantiate drawing modules
	drawBox_signal #(
		SCREEN_X,
		SCREEN_Y,
		X_MAX,
		Y_MAX,
		X_BOXSIZE,
		Y_BOXSIZE
	) clearOld (
		clk,
		resetn,
		clearOld_pulse,
		
		old_x,	//(x_dir)?(ball_x - RATE):(ball_x + RATE), 	// flip signs since we want the prior point
		old_y,	//(y_dir)?(ball_y - RATE):(ball_y + RATE), 	// same here

		pt_clear_x,
		pt_clear_y,
		
		done_clearOld
	);

	// use startDraw pulse to kickstart the drawNew cycle
	drawBox_signal #(
		SCREEN_X,
		SCREEN_Y,
		X_MAX,
		Y_MAX,
		X_BOXSIZE,
		Y_BOXSIZE
	) drawNew (
		clk,
		resetn,
		done_clearOld||drawNew_pulse,

		ball_x,
		ball_y,

		pt_draw_x,
		pt_draw_y,
		done_drawNew
	);

	wire blk_complete;

	drawBox_signal #(
		SCREEN_X,
		SCREEN_Y,
		X_MAX,
		Y_MAX,
		SCREEN_X, // our "box" is the screen!
		SCREEN_Y
	) black_screen (
		clk,
		resetn,
		blackScreen_pulse,
		
		'd0, // set coordinates to be the top left most pixel to clear full screen
		'd0,	

		blk_x,
		blk_y,
		
		blk_complete
	);
	// while reset is low, pass to control that we are NOT done clearing
	// if its high, normal stuff
	assign done_blackScreen = (resetn)?blk_complete:0;
endmodule