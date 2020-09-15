import strutils

# CPU object declaration
type
    CPU* = object
        opcode: uint16              # Current operation opcode
        memory: array[4096, uint8]  # System memory
        registers: array[16, uint8] # System registers
        indexRegister: uint16       # Current register index
        programCounter: uint16
        gfx: array[64 * 32, uint8]  # Graphics map

        # Hardware timers
        delayTimer: uint8
        soundTimer: uint8

        # Stack used to store instructions
        stack: array[16, uint16]
        stackPointer: uint16

        key: array[16, uint8]       # Stores the current state of the keypad

#[
    Constructor for a CPU object. Needs the ROM name to be loaded in memory
]#
proc newCPU*(fileName: TaintedString): CPU =
    result.programCounter = 0x200   # PC starts at 0x200
    result.opcode = 0
    result.indexRegister = 0
    result.stackPointer = 0

#[
    Values describing the Chip8 fontset. A set of 5 values represents a
    character (a character sprite is 4 pixel wide and 5 pixel high).
    An individual value represents the i-th row of a character.
    E.G.
    When drawn, 0xF0 (first value of "0") creates a straight line.
]#
    let chip8_fontset: array[80, uint8] =
        [
        uint8(0xF0), uint8(0x90), uint8(0x90), uint8(0x90), uint8(0xF0), # 0
        uint8(0x20), uint8(0x60), uint8(0x20), uint8(0x20), uint8(0x70), # 1
        uint8(0xF0), uint8(0x10), uint8(0xF0), uint8(0x80), uint8(0xF0), # 2
        uint8(0xF0), uint8(0x10), uint8(0xF0), uint8(0x10), uint8(0xF0), # 3
        uint8(0x90), uint8(0x90), uint8(0xF0), uint8(0x10), uint8(0x10), # 4
        uint8(0xF0), uint8(0x80), uint8(0xF0), uint8(0x10), uint8(0xF0), # 5
        uint8(0xF0), uint8(0x80), uint8(0xF0), uint8(0x90), uint8(0xF0), # 6
        uint8(0xF0), uint8(0x10), uint8(0x20), uint8(0x40), uint8(0x40), # 7
        uint8(0xF0), uint8(0x90), uint8(0xF0), uint8(0x90), uint8(0xF0), # 8
        uint8(0xF0), uint8(0x90), uint8(0xF0), uint8(0x10), uint8(0xF0), # 9
        uint8(0xF0), uint8(0x90), uint8(0xF0), uint8(0x90), uint8(0x90), # A
        uint8(0xE0), uint8(0x90), uint8(0xE0), uint8(0x90), uint8(0xE0), # B
        uint8(0xF0), uint8(0x80), uint8(0x80), uint8(0x80), uint8(0xF0), # C
        uint8(0xE0), uint8(0x90), uint8(0x90), uint8(0x90), uint8(0xE0), # D
        uint8(0xF0), uint8(0x80), uint8(0xF0), uint8(0x80), uint8(0xF0), # E
        uint8(0xF0), uint8(0x80), uint8(0xF0), uint8(0x80), uint8(0x80)  # F
    ]

    for i in countup(0, 80):
        # Load the fontset in memory in the first 80 bytes
       result.memory[i] = chip8_fontset[i]

    # Load game ROM from memory
    var rom: File
    if not rom.open(fileName, fmRead):
        raise newException(IOError, "the specified rom does not exist")

    # Dump the rom content starting from byte 512 in the system memory
    discard(rom.readBytes(result.memory, 512, rom.getFileSize))
    rom.close()

#[
    Procedure called to simulate the Fetch-Decode-Execute cycle of the CPU
]#
proc fetchDecodeExecute(cpu: var CPU) =

    #[
        Since the opcode is 2 bytes long, it has to be fetched from two
        consecutive bytes in memory. The first byte fetched in the position
        specified from the pc will be shifted 8 bits left. It will be combined
        in OR with the next byte in memory.
    ]#
    cpu.opcode = (uint16(cpu.memory[cpu.programCounter]) shl 8) or
        cpu.memory[cpu.programCounter + 1]

    # Opcode decoding
    #[
        The fetched opcode will consist of an operation (first 4 bits), and
        the arguments of the operation. To decode the operation, the opcode
        is combined in AND with 0xF000 to evaluate the first 4 bits.
    ]#
    case cpu.opcode and 0xF000
    of 0x0000:      # Prefix to various operations

        # The last 8 bits are used to distinguish between the operations
        case cpu.opcode and 0x00FF
        of 0x00E0:      # Clears the screen
            discard
        of 0x00EE:      # Returns from a subroutine
            cpu.programCounter = cpu.stack[cpu.stackPointer - 1]
            cpu.stackPointer -= 1
        else:
            echo "Error: unknown opcode (0x", cpu.opcode.toHex, ")\n"

    of 0x1000:      # Goto specified address
        discard
    of 0x2000:      # Call subrutine at specified address
        cpu.stack[cpu.stackPointer] = cpu.programCounter
        cpu.stackPointer += 1
        cpu.programCounter = cpu.opcode and 0x0FFF

    of 0x3000:      # Skip the next instruction if the specified register
                    # equals to a literal
        discard
    of 0x4000:      # Skip the next instruction if the specified register
                    # is not equal to a literal
        discard
    of 0x5000:      # Skip the next instruction if the specified registers
                    # are equal
        discard
    of 0x6000:      # Set the specified register to a literal
        discard
    of 0x7000:      # Add to the specified register a literal
        discard
    of 0x8000:      # Prefix of operations regarding the registers
                    # the first register specified is referred as X
                    # the second register specified is regerred as Y

        case cpu.opcode and 0x000F
        of 0x0000:      # Assign the value of Y to X
            discard
        of 0x0001:      # Set the value of X to X OR Y
            discard
        of 0x0002:      # Set the value of X to X AND Y
            discard
        of 0x0003:      # Set the value of X to X XOR Y
            discard
        of 0x0004:      # Set the value of X to X + Y

            if(cpu.registers[((cpu.opcode and 0x00F0) shr 4)] >
                uint8(0xFF) - cpu.registers[((cpu.opcode and 0x0F00) shr 8)]):
                    # In case of carry, V[F] is set to 1
                    cpu.registers[0xF] = 1
            else:
                    cpu.registers[0xF] = 0
            try:
                cpu.registers[((cpu.opcode and 0x0F00) shr 8)] +=
                    cpu.registers[((cpu.opcode and 0x00F0) shr 4)]
            except OverflowError:
                cpu.registers[((cpu.opcode and 0x0F00) shr 8)] = 0
                    
            cpu.programCounter += 2

        of 0x0005:      # Set the value of X to X - Y
            discard
        of 0x0006:      # Store the least significant bit of X in VF
                        # and shift right X by 1
            discard
        of 0x0007:      # Set X to Y - X
            discard
        of 0x000E:      # Store the most significant bit of X in VF and
                        # shift right X by 1
            discard
        else:
            echo "Error: unknown opcode (0x", cpu.opcode.toHex, ")\n"

    of 0x9000:      # Skip the next instruction if X != Y
        discard
    of 0xA000:      # Set the value of the IndexRegister to a literal
        discard
    of 0xB000:      # Set the program counter to a literal plus V0
        discard
    of 0xC000:      # Set the register X to the result of a bitwise AND
                    # between a literal and a 4 bit random number
        discard
    of 0xD000:      # Draw a sprite of 8pixel width and N + 1 pixel height
                    # at coordinate (X, Y)
        discard
    of 0xE000:      # Prefix to operations regarding key pressure

        case cpu.opcode and 0x00FF
        of 0x009E:      # Skip the next instruction if the key stored in VX
                        # is pressed
            discard
        of 0x00A1:      # Skip the next instruction if the key stored in VX
                        # is not pressed
            discard
        else:
            echo "Error: unknown opcode (0x", cpu.opcode.toHex, ")\n"

    of 0xF000:          # Prefix to various operations

        case cpu.opcode and 0x00FF
        of 0x0007:          # Set VX to the value of the delay timer
            discard
        of 0x000A:          # Key press awaited and stored in X
            discard
        of 0x0015:          # Set delay timer to the content of X
            discard
        of 0x0018:          # Set the sound timer to the content of X
            discard
        of 0x001E:          # Add to the index register the content of X
            discard
        of 0x0029:          # Set the index register to the location of the
                            # character stored in X
            discard
        of 0x0033:          # BCD
            discard
        of 0x0055:          # Dump the content of the registers from 0 to X
                            # in the system memory, starting from the index
                            # register (left unmodified)
            discard
        of 0x0065:          # Load the content of the first n bytes from the
                            # index register intro the registers 0 to X
                            # the index register is left unmodified
            discard
        else:
            echo "Error: unknown opcode (0x", cpu.opcode.toHex, ")\n"

    else:
        echo "Error: unknown opcode (0x", cpu.opcode.toHex, ")\n"

# Emulates a CPU cycle
proc emulateCycle*(cpu: var CPU) =

    cpu.fetchDecodeExecute

    if cpu.delayTimer > uint8(0):
        cpu.delayTimer -= 1

    if cpu.soundTimer > uint8(0):
        cpu.soundTimer -= 1
