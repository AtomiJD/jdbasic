%import syslib
%import textio
%encoding iso

error {
    ubyte number = 0
    ubyte state = 0

    sub clear() {
        number = 0
        state = 0
    }

    sub set(ubyte rnumber) {
        number = rnumber
        state = 1
    }

    sub get() -> ubyte {
        return number
    }

    sub print() {
        txt.print(errtext.txttable[number])
        txt.print(" in line ")
        txt.print_uw(main.linenr)
        txt.nl()
    }
}

errtext {
    str[] txttable = [
        "none",
        "Syntax Error",
        "Command not expected",
        "Failed to load file.",
        "If with no endif found",
        "open function found",
        "next not matching for"
    ]
}
