package dev.garrycraft.bridge;

import java.lang.foreign.Arena;
import java.lang.foreign.FunctionDescriptor;
import java.lang.foreign.Linker;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.SymbolLookup;
import java.lang.invoke.MethodHandle;
import static java.lang.foreign.ValueLayout.*;

/** Monotonic clock shared with the native Source module. Adapted from SkyCraft.
 * Windows reads the performance counter; Linux reads clock_gettime(CLOCK_MONOTONIC),
 * which is the same clock the native module reports through platform::nowSeconds. */
public final class BridgeClock {
    private static final boolean WINDOWS = System.getProperty("os.name", "").startsWith("Windows");
    // Windows reads one 64-bit counter; Linux reads a 16-byte timespec.
    private static final MemorySegment OUT = WINDOWS
        ? Arena.global().allocate(JAVA_LONG)
        : Arena.global().allocate(16);
    private static final MethodHandle COUNTER;
    private static final double FREQUENCY;
    private static final int CLOCK_MONOTONIC = 1;
    static {
        var linker = Linker.nativeLinker();
        if (WINDOWS) {
            var kernel = SymbolLookup.libraryLookup("kernel32", Arena.global());
            COUNTER = linker.downcallHandle(kernel.find("QueryPerformanceCounter").orElseThrow(), FunctionDescriptor.of(JAVA_INT, ADDRESS));
            var frequency = linker.downcallHandle(kernel.find("QueryPerformanceFrequency").orElseThrow(), FunctionDescriptor.of(JAVA_INT, ADDRESS));
            try {
                int result = (int) frequency.invokeExact(OUT);
                if (result == 0) throw new IllegalStateException("Performance counter unavailable");
                FREQUENCY = OUT.get(JAVA_LONG, 0);
            } catch (Throwable error) { throw new ExceptionInInitializerError(error); }
        } else {
            // The linker's default lookup resolves libc symbols without a path.
            SymbolLookup libc = linker.defaultLookup();
            if (libc.find("clock_gettime").isEmpty()) libc = SymbolLookup.loaderLookup();
            if (libc.find("clock_gettime").isEmpty()) {
                SymbolLookup explicitLibc = null;
                for (String candidate : new String[] {"/lib/x86_64-linux-gnu/libc.so.6",
                    "/lib64/libc.so.6", "/usr/lib/libc.so", "/lib/libc.so.6"}) {
                    try {
                        explicitLibc = SymbolLookup.libraryLookup(candidate, Arena.global());
                        break;
                    } catch (IllegalArgumentException ignored) { }
                }
                if (explicitLibc == null) throw new ExceptionInInitializerError("clock_gettime unavailable");
                libc = explicitLibc;
            }
            COUNTER = linker.downcallHandle(libc.find("clock_gettime").orElseThrow(),
                FunctionDescriptor.of(JAVA_INT, JAVA_INT, ADDRESS));
            FREQUENCY = 1_000_000_000.0;
        }
    }
    private BridgeClock() {}
    public static synchronized double seconds() {
        try {
            if (WINDOWS) {
                int result = (int) COUNTER.invokeExact(OUT);
                if (result == 0) throw new IllegalStateException("Performance counter unavailable");
                return OUT.get(JAVA_LONG, 0) / FREQUENCY;
            }
            int result = (int) COUNTER.invoke(CLOCK_MONOTONIC, OUT);
            if (result != 0) throw new IllegalStateException("Monotonic clock unavailable");
            return OUT.get(JAVA_LONG, 0) + OUT.get(JAVA_LONG, 8) / FREQUENCY;
        } catch (Throwable error) { throw new IllegalStateException("Could not read monotonic clock", error); }
    }
}
