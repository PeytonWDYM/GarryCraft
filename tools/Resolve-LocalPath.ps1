param([Parameter(Mandatory)][string]$File)
$ErrorActionPreference = 'Stop'
# Windows can redirect packaged-app paths. Launchers need the file's actual path.
if (-not ('GarryCraftLocalPath' -as [type])) {
    Add-Type @'
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
public static class GarryCraftLocalPath {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern uint GetFinalPathNameByHandle(System.IntPtr handle, StringBuilder path, uint length, uint flags);
    public static string Resolve(string file) {
        using (var stream = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete)) {
            var path = new StringBuilder(32768);
            if (GetFinalPathNameByHandle(stream.SafeFileHandle.DangerousGetHandle(), path, 32768, 0) == 0)
                throw new System.ComponentModel.Win32Exception();
            var result = path.ToString();
            return result.StartsWith(@"\\?\UNC\") ? @"\\" + result.Substring(8) : result.Substring(4);
        }
    }
}
'@
}
[GarryCraftLocalPath]::Resolve($File)
