# JPU - Simple Homebrew CPU

This is a simple 16 bit CPU, using a MIPS-like "RiSC-16 Instruction-Set Architecture" defined here: http://www.eng.umd.edu/~blj/RiSC/RiSC-isa.pdf

The CPU is written in VHDL, intended to (eventually) run on a Xilinx Spartan-6 VHDL. Included is a
Xilinx ISE project file, which can be run using the (free) Xilinx web-pack ISE.  Also included is
the JPUasm assembler written in python.  It reads .asm assembly file and outputs a .MIF file that
is read by Xilinx ISE to initialize the BlockRAM.

The included assembly program "laplace.asm" is a minor reformatting of a program found here:
https://www.ece.umd.edu/~blj/RiSC/laplace.s  This program computes the static electric potential
in a square cavity with different voltage applied to each wall. The result can be seen by inspecting
the RAM in the iSim memory editor, though convergence is quite slow and requires many iterations

Steps to build and simulate:
1) Install Xilinx ISE from here: https://www.xilinx.com/products/design-tools/ise-design-suite/ise-webpack.html
2) Load the JPU.xise project and generate the BlockRAM core
3) Run the assembler to generate the MIF file in the JPU/ipcore_dir directory e.g.:
      python JPUasm.py -i laplace.asm -o ../JPU/ipcore_dir/blockram.mif
      Note this must be done after BlockRAM core is (re)generated in ISE, as that overwrites the MIF file
4) Simulate the CPU by choosing the "Simulation" view in the ISE Design panel, and clicking "Simulate
    Behavioral Model". This will load Xilinx iSim, and the values of the Registers and other signals
    should be seen in the wave editor