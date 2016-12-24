#
# JPUasm.py
# author: Jon Doane
# created: 12/16/16
# Simple Assembler for JPU CPU project
# currently writes output in Xilinx MIF file format (binary strings)
#
import sys, getopt
import re

#instruction set per RiSC-16 architecture: http://www.eng.umd.edu/~blj/RiSC/RiSC-isa.pdf
#opcode['instruction'] = (opcode, optype)
#optype:  R=register, I=immediate or label
opcodes = {'add': (0,'RRR'),    #Syntax:    add $a, $b, $c
                                #Op:        $a = $b + $c (carry discarded)
                                #
           'addi': (1,'RRI'),   #Syntax:    addi $a, $b, imm (7 bit signed immediate)
                                #Op:        $a = $b + imm
                                #
           'nand': (2, 'RRR'),  #Syntax:    nand $a, $b, $c
                                #Op:        $a = $b nand $c (bitwise nand)
                                #
           'lui': (3, 'RI'),    #Syntax:    lui $a, imm (16 bit unsigned immediate)
                                #Op:        $a(15 downto 6) = imm(15 downto 6)
                                #
           'lw': (4, 'RRI'),    #Syntax:    lw  $a, $b, imm  (imm is 7 bit signed offset or equivalent label)
                                #Op:        $a = MEM[$b+imm]
                                #
           'sw': (5, 'RRI'),    #Syntax:    sw  $a, $b, imm  (imm is 7 bit signed offset or equivalent label)
                                #Op:        MEM[$b+imm] = $a
                                #
           'beq': (6, 'RRI'),   #Syntax:    beq  $a, $b, imm  (imm is 7 bit signed offset or equivalent label)
                                #Op:        if $a==$b then PC = PC+1+imm
                                #
           'jalr': (7, 'RR')}   #Syntax:    jalr $a, $b
                                #Op:        $a=PC+1, PC = $b
                                #same opcode generates an interrupt when $a=$b=0, with int code given by lowest 7 bits

#pseudoops map to other op-codes
pseudoops = {'nop': (0,''),         #Equivalent to add $0, $0, $0
           'movi': (1, 'RI'),        #Equivalent to addi $r, $0, imm (7 bit signed immediate)
           'halt': (7,'')}          #Equivalent to jalr $0, $0, with imm=1

# used in .data section, these "instructions" encode data in memory 
datatypes = ['.ascii',       # .ascii 'String Literal'
            '.asciiz',      # .asciiz 'String Literal' (null terminated)
            '.word',        # .word 10, 30, 55    (16-bit signed)
            '.fill',        # .fill 10, 30, 55    (same as .word)
            '.space']       # .space N           (reserve N words)


comment_delim = ';%#'                
sections = ['.data', '.text']
reserved = opcodes.keys() + pseudoops.keys() + datatypes + sections

#Define Exceptions for error handling.
class Error(Exception):
    def __init__(self, message):
        self.message = message

#includes lineinfo object
class ParseError(Error):
    def __init__(self, line, message):
        self.line = line
        self.message = message


# Define object with info about each line in the program
# lineinfo.parsed: parsed line (e.g. ws stripped, comments removed, etc) 
# lineinfo.raw: unparsed line, direct from listing 
# lineinfo.linenum: line number in program listing
# lineinfo.section: '.text' or '.data'
# lineinfo.address: address of instruction/data in executable
class lineinfo:
    def __init__(self, parsed, raw, linenum, section, address):
        self.parsed = parsed
        self.raw = raw
        self.linenum = linenum
        self.section = section
        self.address = address


def main(argv):
    try:
        inputfile = ''
        outputfile = ''
        debugfile = ''

        try:
            opts, args = getopt.getopt(argv[1:],'hi:o:d:')
        except getopt.GetoptError:
            raise Error('JPUasm.py -i <inputfile> -o <outputfile> [-d <debugfile>]')
        for opt, arg in opts:
            if opt == '-h':
                print('JPUasm.py -i <inputfile> -o <outputfile> [-d <debugfile>]')
                sys.exit()
            elif opt == '-i':
                inputfile = arg.strip()
                #print('Input file is ' + inputfile)
            elif opt=='-o':
                outputfile = arg.strip()
                #print('Output file is ' + outputfile)
            elif opt == '-d':
                debugfile = arg.strip()
        if len(inputfile)==0:
            print('<inputfile> not specified')
            print('Usage: JPUasm.py -i <inputfile> -o <outputfile> [-d <debugfile>]')
            sys.exit(2)
        if len(outputfile)==0:
            print('<outputfile> not specified')
            print('Usage: JPUasm.py -i <inputfile> -o <outputfile> [-d <debugfile>]')
            sys.exit(2)
                        
        #asm_fname = 'prog.asm'
        #machine_fname = '..\\JPU\\ipcore_dir\\blockram.mif'
        asm_fname = inputfile
        machine_fname = outputfile
        
        fp = open(asm_fname, 'r')    
        program = []
        for listingindex,rawline in enumerate(fp):
            #program is a list of lines
            program.append(lineinfo(rawline, rawline, listingindex+1, None, None))
        fp.close()

        #preparse
        program, instructions, symboltable = preparse(program)

        #parse instructions
        for line in program:
            if line.section=='.text':
                instructions[line.address] = parseinstructionline(line, symboltable)

        #Write MIF file...            
        fm = open(machine_fname, 'w')
        for inst in instructions:
            bitstr = "{:016b}".format(inst)            
            if inst<0 or inst >2**16-1:
                raise Error('Compiler Error, instruction out of range: ' + str(inst))
            fm.write(bitstr+'\n')
        fm.close()

        #Debug file prints raw program listing with corresponding memory address
        if len(debugfile)>0:
            print('Writing debug file to:' + debugfile)
            fd = open(debugfile, 'w')
            fd.write('Addr  | Code\n')
            fd.write('------------------------------------------------------\n')
            for line in program:
                if line.address>=0:
                    fd.write(str(line.address) +  ' '*(6-len(str(line.address))) + '| ' + line.raw)
            fd.close()
        
        
        print(asm_fname + ' assembled successfully')
        print(str(len(program)) + ' lines of code')
        print(str(len(instructions)) + ' words in program')
        print('Writing to:' + machine_fname)

    except ParseError as err:
        print('(' + str(err.line.linenum) + '):' + err.line.raw)
        print(err.message)
        sys.exit(2)
    except Error as err:
        print(err.message)
        sys.exit(2)

#########################################
# preparse()
#########################################
# creates list of instructions
# creates symboltable with line labels
# parses data
#
#arguments:
#    program        list of lineinfo objects representing the assy program
#returns:
#    program        list of lineinfo objects representing the assy program (updated by parser)
#    instructions   list of integers representing machine language instructions (and data)
#    symboltable    dictionary to store symbols (e.g. labels with corresponding address)
#
def preparse(program):
    symboltable = {}        #dictionary to store symbols (e.g. labels with corresponding address)
    instructions = []       #list of integers representing machine language instructions (and data)
    currentsection = ''     #remember the current section
    newlabel = False        #flag when label is encountered
    
    for line in program:
        #Check for comments
        #match everything preceeding an unescaped comment
        commentmatch = re.match(r'^(.*?)(?<!\\)['+comment_delim+'].*$', line.parsed)    
        if commentmatch:
            line.parsed = commentmatch.group(1)
        #replace any escaped comment delimiters with unescaped char (required to support comment chars in string literals)
        for comment_char in comment_delim:
            line.parsed.replace('\\'+comment_char, comment_char)            

        #remove leading/trailing whitespace
        line.parsed = line.parsed.strip()

        if len(line.parsed)==0:
            #Empty line...
            continue
        
        #section indicators must be on own line, so they are all that is left after stripping ws and comments 
        if line.parsed in sections:
            currentsection = line.parsed            #mark section for this and subsequent lines
            continue                                #stop parsing this line and move on

        if currentsection=='':
            raise ParseError(line, 'Program must begin with valid section directive (e.g. .data, .text)')
        line.section = currentsection
        
        #check for labels
        labelmatch = re.match(r'\s*([\w_]+):(.*)', line.parsed)    #match for alphanumeric and underscores followed by colon
        if labelmatch:
            labelname = labelmatch.group(1)
            if labelname in reserved:
                raise ParseError(line, 'Label name ' + labelname + ' is reserved')
            #line contains valid label
            line.parsed = labelmatch.group(2).strip()   #remove label and strip ws from line
            #this line may be empty, so we don't yet know the corresponding address for the label
            #flag that we have a new label so that we can associate with next nonempty line
            newlabel = True

        if len(line.parsed)==0:
            #Empty line...
            continue

        #line is nonempty - at this point we know it corresponds to instruction or data machinecode word
        #instruction/data will be stored at: instructions[line.address]
        line.address = len(instructions)    
        
        if newlabel:
            symboltable[labelname] = line.address    #store label with current address
            newlabel = False                        #we have now associated label, so clear flag

        #single data lines can result in multiple machinecode words
        if currentsection=='.data':
            for dataword in parsedataline(line):
                instructions.append(dataword)
        elif currentsection=='.text':
            #instructions get parsed later after we have built the symbol table
            #insert an empty instruction for a placeholder
            instructions.append(None)
        else:
            raise ParseError(line, 'This shouldn\'t happen, unknown section type ' + currentsection)
    return program, instructions,symboltable


#########################################
# parsedataline()
#########################################
# parse line of code within .data section
#
#arguments:
#    line           lineinfo object with line of code for data "instruction"
#returns:
#    datalist       list of integers corresponding to the words represented by the data "instruction"
#
def parsedataline(line):
    datalist = [] #empty list to store data

    linesplit = line.parsed.replace('\t', ' ').partition(' ') #partition tokens on tab or space
    #there should be at least two tokens and separator
    if len(linesplit) <3:
        raise ParseError(line, 'Invalid data line format')
    datatype = linesplit[0]
    if not datatype in datatypes:
        raise ParseError(line, 'Unknown data type: '+ datatype)

    #we can't use linesplit[2] to recover data, since we removed tabs which may affect string literals
    #instead, partition line again on datatype 
    datastr = line.parsed.partition(datatype)[2].strip();
    if datatype=='.ascii' or datatype=='.asciiz':                 #ascii character string
        if datastr[0] != datastr[-1] or datastr[0] != "\'" or datastr[0] != "\"":
            raise ParseError(line, 'Data type ' + datatype + 'must be enclosed in quotes (\' or \")')
        datastr = datastr[1:-1]   #strip quotes
        if datatype=='.asciiz':
            #.asciiz adds add null termination
            datastr += chr(0)

        #pack ascii,  two chars per 16bit word
        for i in range(0, len(datastr), 2):                             #iterate through every other character
            if i<len(datastr)-1:                                        #at least 2 chars left...
                dataword = (ord(datastr[i]) << 8) + ord(datastr[i+1])   #combine two characters into 16bit word
            else:                                                       #last character in string
                dataword = ord(datastr[i]) << 8
            datalist.append(dataword)
    elif datatype=='.fill' or datatype=='.word':                  #signed 16-bit int
        datastrlist = datastr.split(',')                                #list of values, comma delimited
        for dataitemstr in datastrlist:
            dataword = int2bits_signed(str2int(dataitemstr),16)
            datalist.append(dataword)
# don't implement byte for now, since we really dont yet support byte-level addressing
#         if datatype=='.byte':
#             data = parseimmediate(datastr)
#             if data==None
#                 return (False, 'invalid data value')
#             if data>0xFF or data<-0x7F
#                 return (False, 'value out of range')
#             datalist.append(data)
    elif datatype=='.space':                                         #reserve multiple words (and zero)
        numwords = int2bits_unsigned(str2int(datastr),8)                #limit to 255 words
        datalist += [0]*numwords
    return datalist

#########################################
# parseinstructionline()
#########################################
# parse line of code within .data section
#
#arguments:
#    line           lineinfo object with line of code for instruction
#    symboltable    dictionary of symbols (e.g. labels with corresponding address)
#returns:
#    instruction    integer corresponding to instruction
#
def parseinstructionline(line,symboltable):
    try:
        linesplit = line.parsed.replace('\t', ' ').partition(' ') #split into cmd and args, delimited by tab or space
        op = linesplit[0].lower()
        if op in opcodes:
            opcode = opcodes[op][0]
            optype = opcodes[op][1]
        elif op in pseudoops:
            opcode = pseudoops[op][0]
            optype = pseudoops[op][1]
        else:
            raise ParseError(line,'Invalid instruction: ' + op)
        args = linesplit[2]             #remaining string is args
        arglist = args.split(',')       #list of arguments
        argvallist = [];
        while '' in arglist:
            arglist.remove('')              #remove empty strings
        if len(arglist) != len(optype):
            raise ParseError(line,'Improper number of arguments for instruction')
        for argtype in optype:
            arg = arglist.pop(0).strip();
            if argtype=='R':
                parseresult = parsereg(arg)
            elif argtype=='I':
                if arg in symboltable:
                    if op=='beq':
                        #bez uses relative address, so we must compute offset relative to current address
                        #PC + 1 + immediate = destination 
                        #immediate = destination - (PC + 1) 
                        parseresult = symboltable[arg] - (line.address+1)
                    else:
                        parseresult = symboltable[arg]
                else:
                    parseresult = str2int(arg)
            argvallist.append(parseresult)

        #handle pseudo instructions
        if op=='nop':
            instruction = 0
            return instruction
        elif op=='movi':
            immediate = int2bits_signed(argvallist[1],7)
            instruction = (opcode << 13) + \
                        (argvallist[0] << 10) + \
                        immediate
            return instruction
        elif op=='halt':
            int_flag = 1
            instruction = (opcode << 13) + int_flag
            return instruction
        
        if optype=="RRR":
            instruction =   (opcode << 13) + \
                            (argvallist[0] << 10) + \
                            (argvallist[1] << 7) + \
                            argvallist[2]
    #         instruction =   numtobin(opcode, 3)+\
    #                         numtobin(argvallist[0], 3)+\
    #                         numtobin(argvallist[1], 3)+\
    #                         numtobin(0, 4)+\
    #                         numtobin(argvallist[2], 3)
            return instruction
        elif optype=="RRI":
            immediate = int2bits_signed(argvallist[2],7)
            instruction =   (opcode << 13) + \
                            (argvallist[0] << 10) + \
                            (argvallist[1] << 7) + \
                            immediate
            return instruction
        elif optype=="RR":
            instruction =   (opcode << 13) + \
                            (argvallist[0] << 10) + \
                            (argvallist[1] << 7)
            return instruction
        elif optype=="RI":
            #the only RI op is lui.  Load upper 10 bits of 16bit number into 10bit immediate bitfield
            immediate = int2bits_unsigned(argvallist[1],16)>>6
            instruction =   (opcode << 13) + \
                            (argvallist[0] << 10) + \
                            immediate
            return instruction
        raise Error(line, 'This Should not happen - unknown opcode type')

    except Error as err: #catch errors we threw while parsing...
        raise ParseError(line, err.message)    

#parse register string ($0-$7)
def parsereg(arg):
    arg=arg.strip()
    if len(arg)!=2 or arg[0]!='$' or not arg[1].isdigit():
        raise Error('Argument is not a Register')        
    regval = int(arg[1])
    if regval<0 or regval>7:
        raise Error('Valid register range is $0-$7')        
    return regval

#wrap builtin str() with error handling
def str2int(arg):
    arg=arg.strip()
    try:
        argval = int(arg,0)
    except:
        raise Error('Expected an integer value: ' + arg)        
    return argval

#check bounds and return a signed 2s compliment integer
def int2bits_signed(sint, numbits):
    if sint>(2**(numbits-1) - 1) or sint<-2**(numbits-1):
        raise Error(str(sint) + ' out of range for ' + str(numbits) + '-bit signed value')
    return sint & (2**numbits - 1)  #2s compliment

#check bounds
def int2bits_unsigned(uint, numbits):
    if uint<0 or uint>(2**numbits - 1):
        raise Error(str(uint) + ' out of range for ' + str(numbits) + '-bit unsigned value')
    return uint


if __name__ == '__main__':
    main(sys.argv)
    
    
