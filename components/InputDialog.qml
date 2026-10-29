import QtQuick
import ".."

// A Material 3 dialog asking for a line of text, over a scrim, as tremc's
// number prompts: Enter answers, Esc cancels. `check` turns the text into
// the answer, as { value }, or returns a string saying what's wrong with
// it. While open
// it takes every key: the field gets them first (see handleKey).
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

    function ask(title, body, text, confirmText, check, answered) {
        root.title = title;
        root.body = body;
        root.confirmText = confirmText;
        root.check = check;
        onAnswer = answered;
        problem = "";
        field.text = text;
        field.selectAll();
        open = true;
        field.forceActiveFocus();
    }

    function close() {
        open = false;
        onAnswer = null;
        returnFocus?.forceActiveFocus();
    }

    function submit() {
        const answer = check ? check(field.text) : {
            value: field.text
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

            // The launcher's field, outlined while typing into it
            Rectangle {
                width: parent.width
                height: 46
                radius: Theme.radius
                color: Qt.alpha(Theme.surface_container_highest, 1)
                border.width: 2
                border.color: root.problem ? Theme.error : Theme.primary

                TextInput {
                    id: field

                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.on_surface
                    selectionColor: Theme.primary
                    selectedTextColor: Theme.on_primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    clip: true
                    onTextChanged: root.problem = ""

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            root.submit();
                        else if (event.key === Qt.Key_Escape)
                            root.close();
                        else
                            return;
                        event.accepted = true;
                    }
                }
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
