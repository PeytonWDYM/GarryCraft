package dev.garrycraft.bridge;

import java.lang.foreign.Arena;
import java.lang.foreign.FunctionDescriptor;
import java.lang.foreign.Linker;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.SymbolLookup;
import java.lang.invoke.MethodHandle;
import static java.lang.foreign.ValueLayout.*;

/** Windows performance counter shared with the native Source module. Adapted from SkyCraft. */
public final class BridgeClock {
    private static final MemorySegment OUT = Arena.global().allocate(JAVA_LONG);
    private static final MethodHandle COUNTER;
    private static final double FREQUENCY;
    static {
        var kernel = SymbolLookup.libraryLookup("kernel32", Arena.global());
        var linker = Linker.nativeLinker();
        COUNTER = linker.downcallHandle(kernel.find("QueryPerformanceCounter").orElseThrow(), FunctionDescriptor.of(JAVA_INT, ADDRESS));
        var frequency = linker.downcallHandle(kernel.find("QueryPerformanceFrequency").orElseThrow(), FunctionDescriptor.of(JAVA_INT, ADDRESS));
        try {
            int result = (int) frequency.invokeExact(OUT);
            if (result == 0) throw new IllegalStateException("Performance counter unavailable");
            FREQUENCY = OUT.get(JAVA_LONG, 0);
        } catch (Throwable error) { throw new ExceptionInInitializerError(error); }
    }
    private BridgeClock() {}
    public static synchronized double seconds() {
        try {
            int result = (int) COUNTER.invokeExact(OUT);
            if (result == 0) throw new IllegalStateException("Performance counter unavailable");
            return OUT.get(JAVA_LONG, 0) / FREQUENCY;
        } catch (Throwable error) { throw new IllegalStateException("Could not read performance counter", error); }
    }
}
