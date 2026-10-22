pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root
    title: "Actualizaciones"
    scrollable: true

    property var packages: []
    property string errorText: ""
    property string helper: "paru"
    property bool checkedOnce: false
    property bool confirmUpdate: false
    property bool showLog: UpdateManager.running || UpdateManager.logText.length > 0

    property Connections updaterEvents: Connections {
        target: UpdateManager
        function onRevisionChanged(): void { root.refresh(); }
    }

    function refresh(): void {
        if (checker.running || UpdateManager.running) return;
        errorText = "";
        checker.running = true;
    }

    property ScrollBar pageScrollbar: ScrollBar { policy: ScrollBar.AsNeeded }

    Component.onCompleted: {
        root.flickable.ScrollBar.vertical = pageScrollbar;
        refresh();
    }

    property Process updateProcess: Process {
        id: checker
        command: ["python3", Quickshell.shellDir + "/assets/scripts/list_updates.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    root.packages = result.packages;
                    root.errorText = result.errors.join("\n");
                    root.helper = result.helper;
                    root.checkedOnce = true;
                } catch (error) {
                    root.errorText = "No se pudo leer la lista de actualizaciones.";
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) root.errorText = "No se pudo consultar las actualizaciones. Intenta nuevamente.";
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.cappedWidth
        spacing: Tokens.spacing.medium

        StyledText {
            Layout.fillWidth: true
            text: checker.running ? "Buscando actualizaciones en repositorios y AUR…"
                : !root.checkedOnce ? "Consulta las actualizaciones disponibles."
                : root.errorText ? "Consulta incompleta: algunos repositorios no pudieron comprobarse."
                : root.packages.length === 0 ? "El sistema está actualizado."
                : root.packages.length + " paquetes disponibles para actualizar"
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            IconTextButton {
                text: checker.running ? "Consultando…" : "Buscar actualizaciones"
                icon: "refresh"
                enabled: !checker.running && !UpdateManager.running
                onClicked: root.refresh()
            }
            IconTextButton {
                text: UpdateManager.running ? "Actualizando…" : "Actualizar aquí"
                icon: "system_update"
                enabled: !checker.running && !UpdateManager.running && root.checkedOnce && root.packages.length > 0
                onClicked: root.confirmUpdate = true
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: !UpdateManager.running
            text: "Actualiza el sistema y AUR desde este panel. Quickshell pedirá la contraseña en su diálogo de autenticación. Las revisiones y confirmaciones aparecerán en el registro."
            wrapMode: Text.WordWrap
            color: Colours.palette.m3outline
            font: Tokens.font.body.small
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.confirmUpdate
            text: "¿Iniciar la actualización de " + root.packages.length + " paquetes? Revisa la lista antes de continuar. El gestor mostrará y confirmará los cambios definitivos."
            wrapMode: Text.WordWrap
        }

        RowLayout {
            visible: root.confirmUpdate
            IconTextButton {
                text: "Confirmar e iniciar"
                icon: "check"
                onClicked: {
                    root.confirmUpdate = false;
                    root.showLog = true;
                    UpdateManager.start();
                }
            }
            IconTextButton {
                text: "Volver"
                icon: "close"
                onClicked: root.confirmUpdate = false
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: UpdateManager.running || UpdateManager.logText.length > 0
            StyledText {
                Layout.fillWidth: true
                text: UpdateManager.statusText
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                color: UpdateManager.exitCode > 0 ? Colours.palette.m3error : Colours.palette.m3onSurface
            }
            IconTextButton {
                text: root.showLog ? "Ver paquetes" : "Ver progreso"
                icon: root.showLog ? "list" : "receipt_long"
                onClicked: root.showLog = !root.showLog
            }
        }

        StyledProgressBar {
            Layout.fillWidth: true
            visible: UpdateManager.running
            indeterminate: UpdateManager.progress < 0
            value: Math.max(0, UpdateManager.progress)
        }

        StyledText {
            Layout.fillWidth: true
            visible: UpdateManager.running
            text: "Progreso de la operación actual. Responde a las confirmaciones abajo. Puedes cambiar de página; mantén Quickshell abierto hasta finalizar."
            font: Tokens.font.body.small
            color: Colours.palette.m3outline
            wrapMode: Text.WordWrap
        }

        Flickable {
            id: logView
            objectName: "updateLog"
            Layout.fillWidth: true
            Layout.preferredHeight: 420
            Layout.minimumHeight: 240
            Layout.maximumHeight: 420
            flickableDirection: Flickable.VerticalFlick
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            visible: root.showLog
            clip: true
            contentHeight: logArea.implicitHeight
            contentWidth: width
            boundsBehavior: Flickable.StopAtBounds
            onContentHeightChanged: {
                if (followLog.checked && !moving && !dragging) contentY = Math.max(0, contentHeight - height);
            }
            onMovementStarted: followLog.checked = false
            TextArea {
                id: logArea
                width: logView.width
                text: UpdateManager.logText
                textFormat: TextEdit.PlainText
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.WrapAnywhere
                font.family: "monospace"
                font.pixelSize: 13
                color: Colours.palette.m3onSurface
                background: Rectangle { color: Colours.tPalette.m3surfaceContainer; radius: Tokens.rounding.medium }
            }
        }

        CheckBox {
            id: followLog
            visible: root.showLog
            checked: true
            text: "Seguir el registro automáticamente"
            palette.windowText: Colours.palette.m3onSurface
            palette.text: Colours.palette.m3onSurface
            onCheckedChanged: {
                if (checked) logView.contentY = Math.max(0, logView.contentHeight - logView.height);
            }
        }

        RowLayout {
            objectName: "updateReplies"
            Layout.fillWidth: true
            Layout.minimumHeight: implicitHeight
            visible: UpdateManager.running
            StyledTextField {
                id: replyInput
                Layout.fillWidth: true
                placeholderText: "Respuesta al registro (número, selección…)"
                onAccepted: {
                    UpdateManager.reply(text);
                    text = "";
                }
            }
            IconTextButton {
                text: "Enviar"
                icon: "send"
                onClicked: {
                    UpdateManager.reply(replyInput.text);
                    replyInput.text = "";
                }
            }
            IconTextButton { text: "Sí"; icon: "check"; onClicked: UpdateManager.reply("y") }
            IconTextButton { text: "No"; icon: "close"; onClicked: UpdateManager.reply("n") }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.errorText.length > 0
            text: root.errorText
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            color: Colours.palette.m3error
        }

        ListView {
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            visible: !root.showLog
            Layout.fillWidth: true
            Layout.preferredHeight: 420
            Layout.minimumHeight: 240
            Layout.maximumHeight: 420
            clip: true
            reuseItems: true
            spacing: Tokens.spacing.small
            model: root.packages
            delegate: StyledRect {
                id: packageRow
                required property var modelData
                width: ListView.view.width
                implicitHeight: Math.max(details.implicitHeight, 36) + Tokens.padding.medium * 2
                radius: Tokens.rounding.medium
                color: Colours.tPalette.m3surfaceContainer

                IconImage {
                    id: appIcon
                    x: Tokens.padding.medium
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 36
                    visible: !!packageRow.modelData.icon && packageRow.modelData.icon !== "package-x-generic"
                    source: {
                        const icon = packageRow.modelData.icon || "package-x-generic";
                        return icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, "package-x-generic");
                    }
                }

                MaterialIcon {
                    anchors.centerIn: appIcon
                    visible: !appIcon.visible
                    text: "inventory_2"
                    color: Colours.palette.m3outline
                    font: Tokens.font.icon.medium
                }

                ColumnLayout {
                    id: details
                    x: appIcon.x + appIcon.width + Tokens.spacing.medium
                    y: Tokens.padding.medium
                    width: parent.width - x - Tokens.padding.medium
                    spacing: Tokens.spacing.extraSmall
                    StyledText {
                        Layout.fillWidth: true
                        text: packageRow.modelData.name + " · " + packageRow.modelData.source
                        textFormat: Text.PlainText
                        wrapMode: Text.WrapAnywhere
                        font.weight: Font.Medium
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: packageRow.modelData.current + "  →  " + packageRow.modelData.new
                        textFormat: Text.PlainText
                        wrapMode: Text.WrapAnywhere
                        font: Tokens.font.body.small
                        color: Colours.palette.m3outline
                    }
                }
            }
        }
    }
}
