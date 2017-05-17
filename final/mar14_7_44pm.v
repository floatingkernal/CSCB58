module final(SW[17:0], CLOCK_50, CLOCK2_50, KEY[3:0], VGA_CLK, VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, GPIO, HEX0, , HEX1);
	// declare clocks
	// keyboard and game clock
	input [9:0] GPIO;
	input [17:0] SW;
	input CLOCK_50, CLOCK2_50; //50MHz
	input [3:0] KEY;
	output [7:0]VGA_R, VGA_G, VGA_B;  //Red, Green, Blue VGA signals
	output VGA_HS, VGA_VS, VGA_CLK, VGA_BLANK_N; //Horizontal and Vertical sync signals
	output [6:0] HEX0, HEX1;
	wire [3:0] score1_wire, score2_wire;
	wire outclock;
	
	wire [27:0] rd2_out;
	wire [7:0] dc0_out;
	reg Enable;
	wire r_set;
	
	assign r_set = GPIO[8] || GPIO[9];
	
	// start game
	start go(
		.start(r_set), 
		.main_clk(CLOCK_50), 
		.key_clk(CLOCK2_50), 
		.p1_data(GPIO[3:0]), 
		.p2_data(GPIO[7:4]), 
		.VGA_clk(VGA_CLK), 
		.VGA_R(VGA_R), 
		.VGA_G(VGA_G), 
		.VGA_B(VGA_B), 
		.VGA_hSync(VGA_HS), 
		.VGA_vSync(VGA_VS), 
		.blank_n(VGA_BLANK_N), 
		.outclock(outclock));
	
	// clock/game counter rate divider
	RateDivider rd10(CLOCK_50, rd2_out, SW[8], outclock, 28'b0010111110101111000001111111, SW[9]);
	
	always@(posedge CLOCK_50)
	begin
	if (rd2_out == 28'b0000000000000000000000000000)
		Enable = 1'b1;
	else
		Enable = 1'b0;
	end
	
	// showing counter on hex displays
	DisplayCounter dc0(CLOCK_50, dc0_out, r_set, Enable);
	hex_decoder hx0(dc0_out[3:0], HEX0);
	hex_decoder hx1(dc0_out[7:4], HEX1);

endmodule

// start game
module start(start, main_clk, key_clk, p1_data, p2_data, VGA_clk, VGA_R, VGA_G, VGA_B, VGA_hSync, VGA_vSync, blank_n, outclock);
	
	input main_clk, key_clk;
	input [3:0] p1_data;
	input [3:0] p2_data;
	input start;
	output reg [7:0]VGA_R, VGA_G, VGA_B;  //Red, Green, Blue VGA signals
	output VGA_hSync, VGA_vSync, VGA_clk, blank_n; //Horizontal and Vertical sync signals
	wire [9:0] incrementerX; //x pixel
	wire [9:0] incrementerY; //y pixel
	wire update, reset;
	output reg outclock;
	
	wire VGA_display; //is it in the active display area?
	wire VGA_clk; //25 MHz
	wire P1, P2, B, GO; 
	wire lethal, nonLethal;
	
	reg [6:0] p1_size;
	reg p1_lethal_collide, p2_lethal_collide, game_over;
	reg border, found;
	
	wire [4:0] p1_movement;
	reg [9:0] p1_snakeX[0:127];
	reg [8:0] p1_snakeY[0:127];
	reg [9:0] p1_snakeHeadX;
	reg [9:0] p1_snakeHeadY;
	reg p1_snakeHead;
	reg p1_snakeBody;
	reg [3:0] p1_score;
	
	wire [4:0] p2_movement;
	reg [6:0] p2_size;
	reg [9:0] p2_snakeX[0:127];
	reg [8:0] p2_snakeY[0:127];
	reg [9:0] p2_snakeHeadX;
	reg [9:0] p2_snakeHeadY;
	reg p2_snakeHead;
	reg p2_snakeBody;
	reg [3:0] p2_score;

	integer snakeSizeMax = 256;
	integer increment1, increment2, increment3;
	//reg [25:0] food_spawn;
	

	clk_reduce reduce1(
		main_clk, 
		VGA_clk
		); //Reduces 50MHz clock to 25MHz
	
	VGA_gen gen(
		VGA_clk, 
		incrementerX, 
		incrementerY, 
		VGA_display, 
		VGA_hSync, 
		VGA_vSync, 
		blank_n
		);//Generates incrementerX, incrementerY and horizontal/vertical sync signals	
	
	// snake movement
	snakeFSM p1_keyIn(
		key_clk, 
		p1_data, 
		p1_movement, 
		reset
		);
	
	snakeFSM keyIn(
		key_clk, 
		p2_data, 
		p2_movement, 
		reset
		);
		
	// game speed + food updater
	updateClk UPDATE(
		main_clk,
		update
		);
	assign VGA_clk = VGA_clk;
	// border
	always @(posedge VGA_clk)
	begin
		border <= (((incrementerX >= 0) && (incrementerX < 5) || (incrementerX >= 635) && (incrementerX < 701)) || ((incrementerY >= 0) && (incrementerY < 3) || (incrementerY >= 475) && (incrementerY < 529)));
	end
	
	
	// player1 movement
	always@(posedge update)
	begin
	if(start)
	begin
	// snake movement - body moving
		for(increment1 = 127; increment1 > 0; increment1 = increment1 - 1)
			begin
				if(increment1 <= p1_size - 1)
				begin
					p1_snakeX[increment1] = p1_snakeX[increment1 - 1];
					p1_snakeY[increment1] = p1_snakeY[increment1 - 1];
				end
			end
		case(p1_movement)
			5'b00010: p1_snakeY[0] <= (p1_snakeY[0] - 10);
			5'b00100: p1_snakeX[0] <= (p1_snakeX[0] - 10);
			5'b01000: p1_snakeY[0] <= (p1_snakeY[0] + 10);
			5'b10000: p1_snakeX[0] <= (p1_snakeX[0] + 10);
			endcase	
		end
	else if(~start)
	begin
		p1_snakeX[0] = 250;
		p1_snakeY[0] = 250;
		for(increment3 = 1; increment3 < 128; increment3 = increment3+1)
			begin
			p1_snakeX[increment3] = 750;
			p1_snakeY[increment3] = -10;
			end
	end
	
	end
	
		
	always@(posedge VGA_clk)
	begin
		found = 0;
		
		for(increment2 = 1; increment2 < p1_size; increment2 = increment2 + 1)
		begin
			if(~found)
			begin				
				p1_snakeBody = ((incrementerX > p1_snakeX[increment2] && incrementerX < p1_snakeX[increment2]+8) && (incrementerY > p1_snakeY[increment2] && incrementerY < p1_snakeY[increment2]+10));
				found = p1_snakeBody;
			end
		end
	end

	// player 2 movement
	always@(posedge update)
	begin
	if(start)
	begin
	// snake movement - body moving
		for(increment1 = 127; increment1 > 0; increment1 = increment1 - 1)
			begin
				if(increment1 <= p2_size - 1)
				begin
					p2_snakeX[increment1] = p2_snakeX[increment1 - 1];
					p2_snakeY[increment1] = p2_snakeY[increment1 - 1];
				end
			end
		case(p2_movement)
			5'b00010: p2_snakeY[0] <= (p2_snakeY[0] - 10);
			5'b00100: p2_snakeX[0] <= (p2_snakeX[0] - 10);
			5'b01000: p2_snakeY[0] <= (p2_snakeY[0] + 10);
			5'b10000: p2_snakeX[0] <= (p2_snakeX[0] + 10);
			endcase	
		end
	else if(~start)
	begin
		p2_snakeX[0] = 350;
		p2_snakeY[0] = 250;
		for(increment3 = 1; increment3 < 128; increment3 = increment3+1)
			begin
			p2_snakeX[increment3] = 750;
			p2_snakeY[increment3] = 530;
			end
	end
	
	end
	
		
	always@(posedge VGA_clk)
	begin
		found = 0;
		
		for(increment2 = 1; increment2 < p2_size; increment2 = increment2 + 1)
		begin
			if(~found)
			begin				
				p2_snakeBody = ((incrementerX > p2_snakeX[increment2] && incrementerX < p2_snakeX[increment2]+8) && (incrementerY > p2_snakeY[increment2] && incrementerY < p2_snakeY[increment2]+10));
				found = p2_snakeBody;
			end
		end
	end

	
	always@(posedge VGA_clk)
	begin	
		p1_snakeHead = (incrementerX > p1_snakeX[0] && incrementerX < (p1_snakeX[0]+10)) && (incrementerY > p1_snakeY[0] && incrementerY < (p1_snakeY[0]+10));
	end
	
	always@(posedge VGA_clk)
	begin	
		p2_snakeHead = (incrementerX > p2_snakeX[0] && incrementerX < (p2_snakeX[0]+10)) && (incrementerY > p2_snakeY[0] && incrementerY < (p2_snakeY[0]+10));
	end
		
	assign lethal = border || p1_snakeBody || p2_snakeBody;
	//assign nonLethal = food;
	always @(posedge VGA_clk)
		if(1) begin 
			//food_collision<=1;
			p1_size = p1_size+1;
			p2_size = p2_size+1;
			end
		else if(~start) p1_size = 1;										
		else begin
			//food_spawn <= food_spawn + 1;
			//food_collision=0;
			end
	always @(posedge VGA_clk) 
		if(lethal && p1_snakeHead)
			p1_lethal_collide<=1;
		else if( lethal && p2_snakeHead)
			p2_lethal_collide <=1;
		else begin
			p1_lethal_collide=0;
			p2_lethal_collide=0;
			end
	always @(posedge VGA_clk) 
		if(p1_lethal_collide) begin
			p1_score <= p1_score + 1;
			game_over <= 1;
			outclock <= 0;
			end
		else if(p2_lethal_collide) begin
			p2_score <= p2_score + 1;
			game_over <= 1;
			outclock <= 0;
			end
		else if(~start) begin
			game_over<= 0;
			outclock <= 1;
			end
										
	
	// let R determine the color of the food and the game over screen		
	assign P1 = (VGA_display && ((p1_snakeHead||p1_snakeBody) && ~game_over));
	// G determines snake color
	assign P2 = (VGA_display && ((p2_snakeHead||p2_snakeBody) && ~game_over));
	// B determines the border color
	assign B = (VGA_display && (border && ~game_over) );//---------------------------------------------------------------Added border
	assign GO = (VGA_display && game_over);
	// set colors
	always@(posedge VGA_clk)
	begin
		if (P1)begin
			VGA_R = 8'd255;
			VGA_G = 8'd0;
			VGA_B = 8'd0;
			end
		if (P2)begin
			VGA_R = 8'd0;
			VGA_G = 8'd0;
			VGA_B = 8'd0;
			end
		if (B)begin
			VGA_R = 8'd204;
			VGA_G = 8'd0;
			VGA_B = 8'd204;
			end
		if (GO)begin
			VGA_R = 8'd204;
			VGA_G = 8'd0;
			VGA_B = 8'd204;
			end
		if (~P1 && ~P2 && ~B && ~GO) begin
			VGA_R = 8'd255;
			VGA_G = 8'd255;
			VGA_B = 8'd255;
		end
	end

endmodule

module clk_reduce(main_clk, VGA_clk);

	input main_clk; //50MHz clock
	output reg VGA_clk; //25MHz clock
	reg q;

	always@(posedge main_clk)
	begin
		q <= ~q; 
		VGA_clk <= q;
	end
endmodule



module VGA_gen(VGA_clk, incrementerX, incrementerY, VGA_display, VGA_hSync, VGA_vSync, blank_n);

	input VGA_clk;
	output reg [9:0]incrementerX, incrementerY; 
	output reg VGA_display;  
	output VGA_hSync, VGA_vSync, blank_n;

	reg p_hSync, p_vSync; 
	
	integer porchHF = 640; //start of horizntal front porch
	integer syncH = 655;//start of horizontal sync
	integer porchHB = 747; //start of horizontal back porch
	integer maxH = 793; //total length of line.

	integer porchVF = 480; //start of vertical front porch 
	integer syncV = 490; //start of vertical sync
	integer porchVB = 492; //start of vertical back porch
	integer maxV = 525; //total rows. 

	always@(posedge VGA_clk)
	begin
		if(incrementerX === maxH)
			incrementerX <= 0;
		else
			incrementerX <= incrementerX + 1;
	end
	// 93sync, 46 bp, 640 display, 15 fp
	// 2 sync, 33 bp, 480 display, 10 fp
	always@(posedge VGA_clk)
	begin
		if(incrementerX === maxH)
		begin
			if(incrementerY === maxV)
				incrementerY <= 0;
			else
			incrementerY <= incrementerY + 1;
		end
	end
	
	always@(posedge VGA_clk)
	begin
		VGA_display <= ((incrementerX < porchHF) && (incrementerY < porchVF)); 
	end

	always@(posedge VGA_clk)
	begin
		p_hSync <= ((incrementerX >= syncH) && (incrementerX < porchHB)); 
		p_vSync <= ((incrementerY >= syncV) && (incrementerY < porchVB)); 
	end
 
	assign VGA_vSync = ~p_vSync; 
	assign VGA_hSync = ~p_hSync;
	assign blank_n = VGA_display;
endmodule		

// this module calls update to update the clock after a certain time interval, determines game speed (resets food block as well)
module updateClk(main_clk, update);
	input main_clk;
	output reg update;
	reg [21:0]increment;	

	always@(posedge main_clk)
	begin
		// incrementing clock
		increment <= increment + 1;
		// change food block if clock hits this num
		if(increment == 2000000)
		begin
			update <= ~update;
			// reset clock incrementer
			increment <= 0;
		end
	end
endmodule

// module is the FSM for the movement of the snake
module snakeFSM(clk, snake_data, movement, reset);
	// holds data
	input [3:0] snake_data;
	input clk;
	output reg [4:0] movement;
	output reg reset = 0; 
	reg [7:0] code;
	reg [10:0]keyCode, previousCode;
	reg recordNext = 0;
	integer increment = 0;
	
	always@(negedge clk)
	begin
		case(~snake_data)
			4'b0001: movement <= 5'b00010;
			4'b0010: movement <= 5'b10000;
			4'b0100: movement <= 5'b01000;
			4'b1000: movement <= 5'b00100;
			default: movement <= movement;
		endcase
	end	
endmodule

module hex_decoder(hex_digit, segments);
    input [3:0] hex_digit;
    output reg [6:0] segments;
    always @(*)
        case (hex_digit)
            4'h0: segments = 7'b100_0000;
            4'h1: segments = 7'b111_1001;
            4'h2: segments = 7'b010_0100;
            4'h3: segments = 7'b011_0000;
            4'h4: segments = 7'b001_1001;
            4'h5: segments = 7'b001_0010;
            4'h6: segments = 7'b000_0010;
            4'h7: segments = 7'b111_1000;
            4'h8: segments = 7'b000_0000;
            4'h9: segments = 7'b001_1000;
            4'hA: segments = 7'b000_1000;
            4'hB: segments = 7'b000_0011;
            4'hC: segments = 7'b100_0110;
            4'hD: segments = 7'b010_0001;
            4'hE: segments = 7'b000_0110;
            4'hF: segments = 7'b000_1110;   
            default: segments = 7'h7f;
        endcase
endmodule

module DisplayCounter(clk, Q, clear, enable);
	input clk, enable, clear;
	output [7:0] Q;
	reg [7:0] Q;
	always @(posedge clk)
	begin
		if(clear == 1'b0)
			Q <= 0;
		else if(enable == 1'b1)
			Q <= Q + 1'b1;
		else if(enable == 1'b0)
			Q <= Q;
	end
endmodule

module RateDivider(clk, Q, clear, enable, d, ParLoad);
	input clk, enable, clear, ParLoad;
	input [27:0] d;
	output [27:0] Q;
	reg [27:0] Q;
	always @(posedge clk)
	begin
		if(clear == 1'b0)
			Q <= 0;
		else if(ParLoad == 1'b1)
			Q <= d;
		else if(Q == 28'b0000000000000000000000000000)
			Q <= d;
		else if(enable == 1'b1)
			Q <= Q - 1'b1;
		else if(enable == 1'b0)
			Q <= Q;
	end
endmodule


