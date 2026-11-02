param([Parameter(Mandatory = $true)][string]$Script)

$ErrorActionPreference = 'Stop'

try {
    # A job owns the entire command tree, including recursive make and cl/mspdbsrv.
    # Its only handle belongs to this launcher: terminating the launcher also
    # closes the job and kills its children. Monitor CMake as well, because a
    # cancelled CMake process need not terminate execute_process descendants.
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

public static class OpenSSLWindowsCommand
{
    const uint Synchronize = 0x00100000;
    const uint Infinite = 0xffffffff;
    const uint WaitTimeout = 258;
    const uint Cancelled = 1223;

    [StructLayout(LayoutKind.Sequential)]
    struct BasicProcessInformation
    {
        public IntPtr Reserved1, PebBaseAddress, Reserved2A, Reserved2B;
        public IntPtr ProcessId, ParentProcessId;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct BasicJobLimits
    {
        public long ProcessTime, JobTime;
        public uint Flags;
        public UIntPtr MinimumWorkingSet, MaximumWorkingSet;
        public uint ActiveProcesses;
        public UIntPtr Affinity;
        public uint Priority, Scheduling;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct IoCounters
    {
        public ulong ReadOperations, WriteOperations, OtherOperations;
        public ulong ReadBytes, WriteBytes, OtherBytes;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct ExtendedJobLimits
    {
        public BasicJobLimits Basic;
        public IoCounters Io;
        public UIntPtr ProcessMemory, JobMemory, PeakProcessMemory, PeakJobMemory;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct StartupInformation
    {
        public uint Size;
        public string Reserved, Desktop, Title;
        public uint X, Y, XSize, YSize, XChars, YChars, Fill, Flags;
        public ushort ShowWindow, ReservedBytes;
        public IntPtr ReservedData, Input, Output, Error;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct ProcessInformation
    {
        public IntPtr Process, Thread;
        public uint ProcessId, ThreadId;
    }

    [DllImport("ntdll.dll")]
    static extern int NtQueryInformationProcess(IntPtr process, int informationClass,
        ref BasicProcessInformation information, int size, out int returnedSize);
    [DllImport("kernel32.dll")]
    static extern IntPtr GetCurrentProcess();
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr OpenProcess(uint access, bool inherit, uint processId);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr CreateJobObject(IntPtr attributes, string name);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool SetInformationJobObject(IntPtr job, int informationClass,
        ref ExtendedJobLimits information, uint size);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool CreateProcess(string application, StringBuilder command,
        IntPtr processAttributes, IntPtr threadAttributes, bool inheritHandles,
        uint flags, IntPtr environment, string directory,
        ref StartupInformation startup, out ProcessInformation process);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern uint WaitForMultipleObjects(uint count, IntPtr[] handles,
        bool waitAll, uint milliseconds);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool GetExitCodeProcess(IntPtr process, out uint exitCode);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool TerminateProcess(IntPtr process, uint exitCode);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr GetStdHandle(int standardHandle);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool DuplicateHandle(IntPtr sourceProcess, IntPtr source,
        IntPtr targetProcess, out IntPtr target, uint access, bool inherit, uint options);
    [DllImport("kernel32.dll")]
    static extern bool CloseHandle(IntPtr handle);

    static void Check(bool success, string operation)
    {
        if (!success)
            throw new Win32Exception(Marshal.GetLastWin32Error(), operation);
    }

    static IntPtr InheritStandardHandle(int number)
    {
        IntPtr result;
        IntPtr current = GetCurrentProcess();
        Check(DuplicateHandle(current, GetStdHandle(number), current,
            out result, 0, true, 2), "Duplicate standard pipe handle");
        return result;
    }

    public static int Run(string script)
    {
        if (!Path.IsPathRooted(script) || !File.Exists(script) ||
            script.IndexOfAny(new char[] {'"', '\r', '\n', '\0', '%', '!', '&', '|', '<', '>', '^'}) >= 0)
            throw new ArgumentException("Expected an existing absolute command script without shell metacharacters");

        IntPtr parent = IntPtr.Zero, job = IntPtr.Zero;
        var startup = new StartupInformation();
        var process = new ProcessInformation();
        bool assigned = false;
        try
        {
            var basic = new BasicProcessInformation();
            int returned;
            int status = NtQueryInformationProcess(GetCurrentProcess(), 0, ref basic,
                Marshal.SizeOf(typeof(BasicProcessInformation)), out returned);
            if (status < 0)
                throw new InvalidOperationException("Cannot find the calling CMake process: NTSTATUS " + status);
            parent = OpenProcess(Synchronize, false, unchecked((uint)basic.ParentProcessId.ToInt64()));
            Check(parent != IntPtr.Zero, "Open calling CMake process");
            if (WaitForSingleObject(parent, 0) != WaitTimeout)
                return (int)Cancelled;

            job = CreateJobObject(IntPtr.Zero, null);
            Check(job != IntPtr.Zero, "Create command job");
            var limits = new ExtendedJobLimits();
            limits.Basic.Flags = 0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
            Check(SetInformationJobObject(job, 9, ref limits,
                (uint)Marshal.SizeOf(typeof(ExtendedJobLimits))), "Set kill-on-close command job");

            startup.Size = (uint)Marshal.SizeOf(typeof(StartupInformation));
            startup.Flags = 0x100; // STARTF_USESTDHANDLES: retain CMake pipes, never disk log handles.
            startup.Input = InheritStandardHandle(-10);
            startup.Output = InheritStandardHandle(-11);
            startup.Error = InheritStandardHandle(-12);
            string command = Path.Combine(Environment.SystemDirectory, "cmd.exe");
            var arguments = new StringBuilder("\"" + command + "\" /d /s /c \"\"" + script + "\"\"");
            Check(CreateProcess(command, arguments, IntPtr.Zero, IntPtr.Zero, true,
                0x08000004, IntPtr.Zero, null, ref startup, out process),
                "Create suspended command"); // CREATE_NO_WINDOW | CREATE_SUSPENDED
            Check(AssignProcessToJobObject(job, process.Process), "Assign command job");
            assigned = true;
            Check(ResumeThread(process.Thread) != 0xffffffff, "Resume command");

            uint wait = WaitForMultipleObjects(2, new IntPtr[] {parent, process.Process}, false, Infinite);
            if (wait == 0)
                return (int)Cancelled;
            Check(wait == 1, "Wait for command or CMake cancellation");
            uint code;
            Check(GetExitCodeProcess(process.Process, out code), "Read command exit code");
            return unchecked((int)code);
        }
        finally
        {
            if (process.Process != IntPtr.Zero && !assigned)
                TerminateProcess(process.Process, Cancelled);
            if (job != IntPtr.Zero)
                CloseHandle(job); // Also removes any descendants left by a completed command.
            if (process.Process != IntPtr.Zero)
                WaitForSingleObject(process.Process, 10000);
            foreach (IntPtr handle in new IntPtr[] {process.Thread, process.Process,
                startup.Input, startup.Output, startup.Error, parent})
                if (handle != IntPtr.Zero)
                    CloseHandle(handle);
        }
    }
}
'@
    exit [OpenSSLWindowsCommand]::Run([IO.Path]::GetFullPath($Script))
}
catch {
    [Console]::Error.WriteLine('OpenSSL command launcher: ' + $_.Exception.Message)
    exit 1
}
