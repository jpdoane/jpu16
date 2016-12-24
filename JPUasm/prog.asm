#  test_vmw.s   -- by Vince Weaver -- 19 February 2000
#               -- division code by Asher Lazarus
#
# Use numerical methods to approximate Laplace's Equation by Averaging
#              see page 54 Ramo's "Fields and Waves in Electromagnetics"
#
#
#          -----5000V-----    One can find approximations for the voltages
#         |   .   .   .   |     at the internal points of a infinite-square
#         |               |     enclosure, assuming no enclosed charges,
#      3000V  .   .   .  6000V  by iteraviely averaging all neighboring
#         |               |     points throughout the grid.
#         |   .   .   .   |
#         |               |   It takes many hundreds of iterations for the
#          ----10000V-----      approximation to be good, unfortunately
#
#
#/* Here is a c-program that is more or less what the assembly here does */
#  #include <stdio.h>
#
#  #define GRIDX 16
#  #define GRIDY 16
#  #define ITERATIONS 100
#
#  #define GRID_TOP     5000
#  #define GRID_LEFT    3000
#  #define GRID_RIGHT   6000
#  #define GRID_BOTTOM 10000
#
#  short int GRID[GRIDX][GRIDY];
#
#  void fill_grid() {
#     int x,y;
#
#     for(x=0;x<GRIDX;x++) for (y=0;y<GRIDY;y++) {
#        if (y==0) GRID[x][y]=GRID_TOP;
#        else if (x==0) GRID[x][y]=GRID_LEFT;
#        else if (x==(GRIDX-1)) GRID[x][y]=GRID_RIGHT;
#        else if (y==(GRIDY-1)) GRID[x][y]=GRID_BOTTOM;
#        else GRID[x][y]=0;
#     }
#  }
#  
#  void dump_array() {
#      int x,y;
#
#      for(y=0;y<GRIDY;y++) for (x=0;x<GRIDX;x++) {
#         printf("%hd\t",GRID[x][y]);
#         if (x==(GRIDX-1)) printf("\n");
#      }
#  }
#
#  int main() {
#
#     int i,x,y;
#
#     fill_grid();
#     dump_array();
#     printf("\n");
#     for(i=0;i<ITERATIONS;i++) {
#        for(x=1;x<GRIDX-1;x++)
#  	     for(y=1;y<GRIDY-1;y++)
#	        GRID[x][y]=
#                  (GRID[x-1][y]+GRID[x+1][y]+GRID[x][y-1]+GRID[x][y+1])/4;
#        dump_array();
#        printf("\n");
#     }
#  }
#
#  This benchmark implements a 16x16 grid, with a small number of iterations.
#
#  This should exercise many of the RiSC assembly instructions
#       plus a lot of cache and branch prediction.

.text
		movi    $3,GRIDXY       # get the address of the array
		nand	$3,$3,$3		# make 3 negative first by bit-wise not
		addi	$3,$3,1			# then adding 1
		lw		$5,$0,max		# get the total size on the grid
		add		$5,$5,$3		# add in the grid offset
		sw		$5,$0,max		# save our 'quit program' cut-off
begin:	addi    $4,$0,17			# load 17 into r4 [y]
		movi	$3,GRIDXY		# load the addrss of the GRID
		add    	$4,$4,$3         # now at row1 column1
loop1:  addi    $2,$0,14			# we are 14 columns wide

loop2:  lw		$5,$4,1			# load GRID[x+1,y]
		add     $6,$5,$0			# save it in r6
		lw		$5,$4,-1		# load GRID[x-1],y
		add 	$6,$6,$5		# add it into r6
		lw		$5,$4,-16		# load GRID[x,y-1]
		add		$6,$6,$5		# add it into r6
		lw 		$5,$4,16		# load GRID[x,y+1]
		add		$6,$6,$5		# add it into r6

		movi	$5,div_4		# address of divide by 4 routine
		jalr	$1,$5			# call it
		
		sw		$7,$4,0			# store returned average in GRID[x][y]
		addi	$4,$4,1			# increment pointer
		addi	$2,$2,-1		# decrement counter
		beq		$2,$0,done		# have we done 14 yet?
		beq		$0,$0,loop2		# if not keep looping

done:	lui		$1,32768		# highest bit [and test lui]
		lw		$5,$0,max		# load maximum value to watch for
		add		$5,$5,$4		# add to offset
		nand	$5,$5,$1		# mask for top bit [negative]
		nand	$5,$5,$5		# invert to get an and
		beq		$5,$0,done2		# if negative, we are done
		addi	$4,$4,2			# otherwise move to next row
		beq		$0,$0,loop1		# and re-loop

done2:  lw		$5,$0,count		# load the iteration count
		addi	$5,$5,-1		# decrement it
		sw		$5,$0,count		# store it back
		beq		$5,$0,done3		# are we done?
		beq		$0,$0,begin		# if not re-start the loop

done3:	halt					# Game Over

.data
R1:     .fill 0					# Area to back-up registers if they
R2:     .fill 0					# Will be overwritten in function calls
R3:     .fill 0

count:	.fill 35					# 2 iterations
max:	.fill -237				# cut-off for end of array

.text
# input in r6, returns value in r7
div_4:	sw		$2,$0,R2		# back up r2
		sw		$3,$0,R3		# back up r3
		addi	$7,$0,0			# r7=0
		addi	$5,$0,1			# r5=1 ( 0000 0000 0000 0001 b)
		addi	$2,$0,4			# r2=4 ( 0000 0000 0000 0100 b)
loop7:	nand	$3,$6,$2		# mask our input vs *4 bit
		nand    $3,$3,$3		# bitwise-not the result
		beq		$3,$0,loop9		# if zero, that bit not set
		add		$7,$7,$5		# if not, add the /4 mask
loop9:	add		$5,$5,$5		# shift /4 mask left
		add		$2,$2,$2		# shift *4 mask left
		beq		$2,$0,done9		# if *4 has overflown, we are done
		beq		$0,$0,loop7		# if not keep looping
done9:	lw		$2,$0,R2		# restore r2
		lw		$3,$0,R3		# restore r3
		jalr	$0,$1			# return to address in r1
		
.data
GRIDXY:	.fill 5000
	.fill 5000
	.fill 5000
	.fill 5000
	.fill 5000
	.fill 5000
	.fill 5000
	.fill 5000
	.fill 5000
	.fill 5000
	.fill 5000
	.fill 5000
	.fill 5000
	.fill 5000
	.fill 5000
	.fill 5000
	.fill 3000
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 6000
	.fill 3000
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 6000
	.fill 3000
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 6000
	.fill 3000
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 6000
	.fill 3000
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 6000
	.fill 3000
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 6000
	.fill 3000
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 6000
	.fill 3000
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 6000
	.fill 3000
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 6000
	.fill 3000
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 6000
	.fill 3000
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 6000
	.fill 3000
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 6000
	.fill 3000
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 6000
	.fill 3000
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 0
	.fill 6000
	.fill 3000
	.fill 10000
	.fill 10000
	.fill 10000
	.fill 10000
	.fill 10000
	.fill 10000
	.fill 10000
	.fill 10000
	.fill 10000
	.fill 10000
	.fill 10000
	.fill 10000
	.fill 10000
	.fill 10000
	.fill 6000