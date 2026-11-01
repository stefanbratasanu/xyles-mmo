using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class XylesWorldEditorLauncher
{
    [STAThread]
    private static int Main(string[] args)
    {
        string directory = AppDomain.CurrentDomain.BaseDirectory;
        string godot = Path.Combine(directory, "Godot_v4.7.2-stable_win64.exe");
        string scene = Path.Combine(directory, "scenes", "world_editor.tscn");
        if (!File.Exists(godot) || !File.Exists(scene))
        {
            MessageBox.Show("Keep this launcher in the Xyles game folder, beside Godot and the project files.", "Xyles World Editor", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
        try
        {
            var start = new ProcessStartInfo(godot);
            start.WorkingDirectory = directory;
            string testOptions = args.Length == 1 && args[0] == "--smoke-test"
                ? "--headless --quit-after 5 --log-file \"" + Path.Combine(directory, "logs", "world_editor_launcher_test.log") + "\" "
                : "";
            start.Arguments = testOptions + "--path \"" + directory.TrimEnd('\\') + "\" res://scenes/world_editor.tscn";
            start.UseShellExecute = false;
            Process.Start(start);
            return 0;
        }
        catch (Exception error)
        {
            MessageBox.Show("Could not start the world editor: " + error.Message, "Xyles World Editor", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
