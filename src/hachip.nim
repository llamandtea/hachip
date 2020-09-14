import os
import strutils
import sdl2

type
    CPU = object
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

proc newCPU(fileName: TaintedString): CPU =
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

# Emulates a CPU cycle
proc emulateCycle(cpu: CPU): CPU =

    # Opcode fetching
    #[
        Since the opcode is 2 bytes long, it has to be fetched from two
        consecutive bytes in memory. The first byte fetched in the position
        specified from the pc will be shifted 8 bits left. It will be combined
        in OR with the next byte in memory.
    ]#
    result.opcode = (uint16(result.memory[result.programCounter]) shl 8) or
        result.memory[result.programCounter + 1]

    # Opcode decoding
    #[
        The fetched opcode will consist of an operation (first 4 bits), and
        the arguments of the operation. To decode the operation, the opcode
        is combined in AND with 0xF000 to evaluate the first 4 bits.
    ]#
    case result.opcode and 0xF000
    of 0x0000:      # Prefix to various operations

        # The last 8 bits are used to distinguish between the operations
        case result.opcode and 0x00FF
        of 0x00E0:      # Clears the screen
            discard
        of 0x00EE:      # Returns from a subroutine
            discard
        else:
            echo "Error: unknown opcode (0x", result.opcode.toHex, ")\n"

    of 0x1000:      # Goto specified address
        discard
    of 0x2000:      # Call subrutine at specified address
        discard
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

        case result.opcode and 0x000F
        of 0x0000:      # Assign the value of Y to X
            discard
        of 0x0001:      # Set the value of X to X OR Y
            discard
        of 0x0002:      # Set the value of X to X AND Y
            discard
        of 0x0003:      # Set the value of X to X XOR Y
            discard
        of 0x0004:      # Set the value of X to X + Y
            discard
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
            echo "Error: unknown opcode (0x", result.opcode.toHex, ")\n"

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

        case result.opcode and 0x00FF
        of 0x009E:      # Skip the next instruction if the key stored in VX
                        # is pressed
            discard
        of 0x00A1:      # Skip the next instruction if the key stored in VX
                        # is not pressed
            discard
        else:
            echo "Error: unknown opcode (0x", result.opcode.toHex, ")\n"

    of 0xF000:          # Prefix to various operations

        case result.opcode and 0x00FF
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
            echo "Error: unknown opcode (0x", result.opcode.toHex, ")\n"

    else:
        echo "Error: unknown opcode (0x", result.opcode.toHex, ")\n"

    if result.delayTimer > uint8(0):
        result.delayTimer -= 1

    if result.soundTimer > uint8(0):
        result.soundTimer -= 1

proc main =

    var cpu: CPU

    when declared(commandLineParams):
        let args = commandLineParams()

        if args.len > 0:
            try:
                cpu = newCPU(args[0])

            except IOError:
                let e = getCurrentException()
                echo e.name, ": ", getCurrentExceptionMsg()
                return

        else:
            raise newException(Exception, "Error: no ROM specified.")

    while true:
        # Emulates one CPU cycle
        cpu = cpu.emulateCycle()


when isMainModule:
  main()
