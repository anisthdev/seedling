import QtQuick
import ".."

// A Material 3 dialog asking for a line of text, over a scrim, as tremc's
// number prompts: Enter answers, Esc cancels. `check` turns the text into
// the answer, as { value }, or returns a string saying what's wrong with
// it. For a path, `options` turns on Tab completion and Up/Down choices
// (see PathField). While open it takes every key: the field gets them
// first (see handleKey).
Item {
    id: root

    property bool open: false
    property string title
    property string body
    property string confirmText
    property var check: null
    property var onAnswer: null
    property string problem
    // The height it needs, for the menu to make room
    readonly property real wanted: open ? content.implicitHeight + 48 + 48 : 0

    // Focus goes back here on closing
    property Item returnFocus: null

    // options: { completion: "files" | "dirs", choices: [paths] }
    function ask(title, body, text, confirmText, check, answered, options) {
        root.title = title;
        root.body = body;
        root.confirmText = confirmText;
        root.check = check;
        onAnswer = answered;
        field.completion = options?.completion ?? "";
        field.choices = options?.choices ?? [];
        field.choice = -1;
        field.text = text;
        problem = "";
        open = true;
        field.takeFocus(true);
    }

    function close() {
        open = false;
        onAnswer = null;
        returnFocus?.forceActiveFocus();
    }

    function submit() {
        const answer = check ? check(field.text) : {
            value: field.expanded
        };
        if (typeof answer === "string") {
            problem = answer;
            return;
        }
        const action = onAnswer;
        close();
        action?.(answer.value);
    }

    // Keys the field left alone: swallowed while open
    function handleKey(event) {
        return true;
    }

    anchors.fill: parent
    visible: open || scrim.opacity > 0

    Rectangle {
        id: scrim

        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
        opacity: root.open ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animFast
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 400)
        height: content.implicitHeight + 48
        radius: 28
        // Opaque, as ConfirmDialog
        color: Qt.alpha(Theme.surface_container_high, 1)
        opacity: scrim.opacity
        scale: 0.94 + 0.06 * scrim.opacity

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: content

            x: 24
            y: 24
            width: parent.width - 48
            spacing: 16

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                text: root.title
                color: Theme.on_surface
                font.pixelSize: 24
                font.weight: Font.Normal
                roundness: Theme.titleRoundness
                wrapMode: Text.WordWrap
            }

            Label {
                anchors.verticalCenter: undefined
                width: parent.width
                text: root.body
                color: Theme.on_surface_variant
                font.weight: Font.Normal
                wrapMode: Text.WordWrap
            }

            PathField {
                id: field

                onTextChanged: root.problem = ""
                onSubmitted: root.submit()
                onCancelled: root.close()
            }

            Label {
                anchors.verticalCenter: undefined
                visible: root.problem !== ""
                width: parent.width
                text: root.problem
                color: Theme.error
                font.pixelSize: 12
                font.weight: Font.Normal
                wrapMode: Text.WordWrap
            }

            Row {
                anchors.right: parent.right
                spacing: 8

                TextButton {
                    text: "Cancel  Esc"
                    onClicked: root.close()
                }

                TextButton {
                    text: `${root.confirmText}  ↵`
                    onClicked: root.submit()
                }
            }
        }
    }
}
