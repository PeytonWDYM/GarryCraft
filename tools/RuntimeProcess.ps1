# Keep process paths literal. Windows PowerShell's Start-Process expands wildcard paths.
Add-Type @'
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
public static class GarryCraftMinecraftProcess {
    public static Process Start(string java, string arguments, string directory, string stdout, string stderr) {
        var output = new StreamWriter(stdout, false, new UTF8Encoding(false)) { AutoFlush = true };
        var errors = new StreamWriter(stderr, false, new UTF8Encoding(false)) { AutoFlush = true };
        var process = new Process {
            StartInfo = new ProcessStartInfo(java, arguments) {
                WorkingDirectory = directory,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                StandardOutputEncoding = Encoding.UTF8,
                StandardErrorEncoding = Encoding.UTF8
            }
        };
        process.OutputDataReceived += (sender, item) => {
            if (item.Data == null) output.Dispose(); else output.WriteLine(item.Data);
        };
        process.ErrorDataReceived += (sender, item) => {
            if (item.Data == null) errors.Dispose(); else errors.WriteLine(item.Data);
        };
        try {
            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();
            return process;
        } catch {
            output.Dispose();
            errors.Dispose();
            process.Dispose();
            throw;
        }
    }
}
'@
