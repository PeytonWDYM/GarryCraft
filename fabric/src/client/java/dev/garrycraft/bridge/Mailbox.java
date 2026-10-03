package dev.garrycraft.bridge;

import java.io.IOException;
import java.lang.invoke.MethodHandles;
import java.lang.invoke.VarHandle;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;

/** A nonblocking, single-writer mailbox per lane. Matches native/src/mailbox.hpp. */
public final class Mailbox implements AutoCloseable {
    private static final int SIZE = 128 * 1024 * 1024;
    private static final int[] CAPACITIES = {64 * 1024, 4 * 1024 * 1024, 16 * 1024 * 1024,
        8 * 1024 * 1024, 16 * 1024 * 1024, 8 * 1024 * 1024, 64 * 1024 * 1024, 8 * 1024 * 1024, 64 * 1024};
    private static final VarHandle INT = MethodHandles.byteBufferViewVarHandle(int[].class, ByteOrder.LITTLE_ENDIAN);
    private final FileChannel file;
    private final MappedByteBuffer buffer;
    private final int[] seen = new int[CAPACITIES.length];

    public Mailbox(Path path) throws IOException {
        Files.createDirectories(path.getParent());
        file = FileChannel.open(path, StandardOpenOption.CREATE, StandardOpenOption.READ, StandardOpenOption.WRITE);
        if (file.size() != SIZE) {
            file.position(SIZE - 1);
            file.write(ByteBuffer.wrap(new byte[1]));
        }
        buffer = file.map(FileChannel.MapMode.READ_WRITE, 0, SIZE);
        buffer.order(ByteOrder.LITTLE_ENDIAN);
    }

    private static int offset(int lane) {
        if (lane < 0 || lane >= CAPACITIES.length) throw new IllegalArgumentException("Invalid bridge lane");
        int offset = 0;
        for (int i = 0; i < lane; i++) offset += 64 + CAPACITIES[i];
        return offset;
    }

    public String receive(int lane) {
        byte[] bytes = receiveBytes(lane);
        return bytes == null ? null : new String(bytes, StandardCharsets.UTF_8);
    }

    public byte[] receiveBytes(int lane) {
        int offset = offset(lane);
        int before = (int) INT.getAcquire(buffer, offset);
        if ((before & 1) != 0 || before == seen[lane]) return null;
        int length = buffer.getInt(offset + 4);
        if (length < 0 || length > CAPACITIES[lane]) throw new IllegalStateException("Invalid bridge payload length");
        byte[] bytes = new byte[length];
        buffer.get(offset + 64, bytes);
        VarHandle.acquireFence();
        if (before != (int) INT.getAcquire(buffer, offset)) return null;
        seen[lane] = before;
        return bytes;
    }

    public void send(int lane, String payload) {
        send(lane, payload.getBytes(StandardCharsets.UTF_8));
    }

    public void send(int lane, byte[] bytes) {
        int offset = offset(lane);
        if (bytes.length > CAPACITIES[lane]) throw new IllegalArgumentException("Bridge payload exceeds lane capacity");
        int writing = ((int) INT.getAcquire(buffer, offset) & ~1) + 1;
        INT.setVolatile(buffer, offset, writing);
        buffer.putInt(offset + 4, bytes.length);
        buffer.put(offset + 64, bytes);
        INT.setRelease(buffer, offset, writing + 1);
    }

    @Override
    public void close() throws IOException { file.close(); }
}
