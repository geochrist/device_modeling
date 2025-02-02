

localparam div_input_clk = (DIVIDE_CLK_IN_BY_2=="TRUE") ? 2 : 1;

localparam clk_in_min_period = (DIVIDE_CLK_IN_BY_2=="TRUE") ? 125000/2 : 125000;
localparam clk_in_max_period = (DIVIDE_CLK_IN_BY_2=="TRUE") ? 2000/2 : 2000;

localparam vco_min_period = 1250;
localparam vco_max_period = 312;

time clk_in_period = 0;
time old_clk_in_period = 0;
time clk_in_start;
time vco_period = vco_min_period;

reg pll_start = 1'b0;
reg vco_clk_start = 1'b0;
reg clk_out_start = 1'b0;
integer vco_count = (PLL_MULT*PLL_DIV*2);
integer div3_count = 1;
reg [3:0] clk_in_count = 4'h0;
reg [3:0] old_clk_in_count = 4'h0;

always begin
  LOCK = 1'b0;
  pll_start = 1'b0;
  clk_in_period = 0;
  clk_in_count = 4'h0;
  old_clk_in_count = 4'h0;
  vco_period = 1250;
  vco_clk_start = 1'b0;
  clk_out_start = 1'b0;
  div3_count = 1;
  vco_count = (PLL_MULT*PLL_DIV*2);
  SERDES_FAST_CLK = 1'b0;
  CLK_OUT = 1'b0;
  CLK_OUT_DIV2 = 1'b0;
  CLK_OUT_DIV3 = 1'b0;
  CLK_OUT_DIV4 = 1'b0;
  #100;
  if (PLL_EN) begin
    pll_start = 1'b1;
    @(negedge PLL_EN, negedge LOCK);
  end else
    @(posedge PLL_EN);
end

always @(posedge pll_start) begin
  repeat(9)
    @(posedge CLK_IN);
  vco_clk_start = 1'b1;
  repeat (10)
    @(posedge SERDES_FAST_CLK);
  @(posedge CLK_IN);
  clk_out_start = 1'b1;      
  repeat (5)
    @(posedge CLK_OUT);
  LOCK = 1'b1;
end

always
  if (vco_clk_start) begin
    if (vco_count==(PLL_MULT*PLL_DIV*2)) begin
      SERDES_FAST_CLK = 1'b0;
      @(posedge CLK_IN);
      vco_count = 1;
    end else begin
      SERDES_FAST_CLK = ~SERDES_FAST_CLK;
      #(vco_period/2);
      vco_count = vco_count + 1;
    end 
  end else begin
    SERDES_FAST_CLK = 1'b0;
    @(posedge CLK_IN);
  end

always @(posedge SERDES_FAST_CLK) begin
  if (clk_out_start) begin
    CLK_OUT = ~CLK_OUT;
    repeat ((PLL_POST_DIV/2)-1)
      @(posedge SERDES_FAST_CLK);
  end else begin
    CLK_OUT = 1'b0;
  end
end

always @(posedge CLK_OUT)
  CLK_OUT_DIV2 = ~CLK_OUT_DIV2;

always @(CLK_OUT)
  if (div3_count==2) begin
    CLK_OUT_DIV3 = ~CLK_OUT_DIV3;
    div3_count = 0;
  end else
    div3_count = div3_count + 1;

always @(posedge CLK_OUT_DIV2)
  CLK_OUT_DIV4 = ~CLK_OUT_DIV4;

always @(posedge CLK_IN)
  if (pll_start) begin
    clk_in_start = $realtime;
    if (LOCK)
      clk_in_count = clk_in_count + 1'b1;

    @(posedge CLK_IN);
    if (clk_in_period == 0)
      old_clk_in_period = $realtime - clk_in_start;
    else
      old_clk_in_period = clk_in_period;

    clk_in_period = $realtime - clk_in_start;
    vco_period = clk_in_period * div_input_clk  * PLL_DIV / PLL_MULT;
    clk_in_start = $realtime;
    if (LOCK)
      clk_in_count = clk_in_count + 1'b1;
    if (clk_in_period < clk_in_max_period) begin
      $display("Warning at time %t: PLL instance %m input clock, CLK_IN, is too fast.", $realtime);
      LOCK = 1'b0;
    end
    if (clk_in_period > clk_in_min_period) begin
      $display("Warning at time %t: PLL instance %m input clock, CLK_IN, is too slow.", $realtime);
      LOCK = 1'b0;
    end
    if ((LOCK==1'b1) && (clk_in_period > old_clk_in_period*1.05) || (clk_in_period < old_clk_in_period*0.95)) begin
      $display("Warning at time %t: PLL instance %m input clock, CLK_IN, changed frequency and lost lock.", $realtime);
      LOCK = 1'b0;
    end
  end

// Checking for proper CLK_IN and VCO frequencies
always
  if (LOCK) begin
    #(5*clk_in_period);
    if (clk_in_count == old_clk_in_count) begin
      $display("Warning at time %t: PLL instance %m input clock, CLK_IN, has stopped.", $realtime);
      LOCK = 1'b0;
    end else
      old_clk_in_count = clk_in_count;
    if (vco_period<vco_max_period) begin
      $display("\nError at time %t: PLL instance %m VCO clock period %0d ps violates minimum period.\nMust be greater than %0d ps.\nTry increasing PLL_DIV or decreasing PLL_MULT values.\n", $realtime, vco_period, vco_max_period);
      $stop;
    end else if (vco_period>vco_min_period) begin
      $display("\nError at time %t: PLL instance %m VCO clock period %0d ps violates maximum period.\nMust be less than %0d ps.\nTry increasing PLL_MULT or decreasing PLL_DIV values.\n", $realtime, vco_period, vco_min_period);
      $stop;
    end
  end else
    @(posedge LOCK);

