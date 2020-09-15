import os
import cpu

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
        cpu.emulateCycle()


when isMainModule:
  main()
