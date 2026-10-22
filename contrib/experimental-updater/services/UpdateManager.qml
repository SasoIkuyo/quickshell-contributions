pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property bool running: updater.running
    property string logText: ""
    property string statusText: ""
    property int exitCode: -1
    property real progress: -1
    property int revision: 0
    property string pendingOutput: ""

    function flushOutput(): void {
        if (!pendingOutput.length) return;
        logText = (logText + pendingOutput).slice(-60000);
        pendingOutput = "";
    }

    Timer {
        interval: 150
        running: root.pendingOutput.length > 0
        repeat: true
        onTriggered: root.flushOutput()
    }

    function start(): void {
        if (running) return;
        logText = "";
        pendingOutput = "";
        progress = -1;
        exitCode = -1;
        statusText = "Preparando la actualización…";
        updater.running = true;
    }

    function reply(text: string): void {
        if (running) updater.write(JSON.stringify({reply: text}) + "\n");
    }

    function receive(line: string): void {
        try {
            const event = JSON.parse(line);
            if (event.event === "output") {
                pendingOutput = (pendingOutput + event.text).slice(-60000);
                const matches = event.text.match(/(\d{1,3})%/g);
                if (matches && matches.length)
                    progress = Math.min(100, parseInt(matches[matches.length - 1])) / 100;
                const lines = event.text.trim().split("\n");
                if (lines.length && lines[lines.length - 1].trim())
                    statusText = lines[lines.length - 1].trim().slice(-180);
            } else if (event.event === "finished") {
                exitCode = event.code;
            }
        } catch (error) {
            logText = (logText + "\n" + line).slice(-60000);
        }
    }

    Process {
        id: updater
        stdinEnabled: true
        command: ["python3", Quickshell.shellDir + "/assets/scripts/run_updates.py"]
        stdout: SplitParser { onRead: data => root.receive(data) }
        stderr: SplitParser {
            onRead: data => root.logText = (root.logText + "\n" + data).slice(-60000)
        }
        onExited: (code, exitStatus) => {
            root.flushOutput();
            root.exitCode = code;
            root.statusText = code === 0 ? "Actualización completada" : "La actualización se detuvo (código " + code + "). Revisa el registro.";
            root.progress = code === 0 ? 1 : -1;
            root.revision++;
        }
    }
}
