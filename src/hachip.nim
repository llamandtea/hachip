import os
import sdl2

type
    CPU = object
        opcode: int16               # Current operation opcode
        memory: array[4096, int8]   # System memory
        registers: array[16, uint8] # System registers
        indexRegister: uint16        # Current register index
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
    result.programCounter = 0x200      # PC starts at 0x200
    result.opcode = 0
    result.indexRegister = 0
    result.stackPointer = 0

    for i in countup(0, 80):
        discard
        # Caricamento del fontset in memoria
#       memory[i] = chip8_fontset[i]

    # Load game ROM from memory
    var rom: File
    if not rom.open(fileName, fmRead):
        raise newException(IOError, "the specified rom does not exist")

    # Dumps the rom content starting from byte 512 in the system memory
    discard(rom.readBytes(result.memory, 512, rom.getFileSize))
    rom.close()

# Emulates a CPU cycle
proc emulateCycle(cpu: CPU) =
    return

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
            raise newException(Exception, "Boh")

    while true:

        # Emulates one CPU cycle
        cpu.emulateCycle()


when isMainModule:
  main()
