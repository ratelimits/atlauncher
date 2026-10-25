import QtQuick 2.12

/* What qml-runner hands this app: its `appId` and launch `params`, set on the root context. Read from this file
   because main.qml's WebOSWindow has its own appId property, which would hide the runner's inside main.qml. */
QtObject {
    readonly property string id: typeof appId !== 'undefined' ? appId : ''
    readonly property var launchParams: typeof params !== 'undefined' ? params : null
}
