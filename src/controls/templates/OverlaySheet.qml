/*
*   Copyright (C) 2016 by Marco Martin <mart@kde.org>
*
*   This program is free software; you can redistribute it and/or modify
*   it under the terms of the GNU Library General Public License as
*   published by the Free Software Foundation; either version 2, or
*   (at your option) any later version.
*
*   This program is distributed in the hope that it will be useful,
*   but WITHOUT ANY WARRANTY; without even the implied warranty of
*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*   GNU Library General Public License for more details
*
*   You should have received a copy of the GNU Library General Public
*   License along with this program; if not, write to the
*   Free Software Foundation, Inc.,
*   51 Franklin Street, Fifth Floor, Boston, MA  2.010-1301, USA.
*/

import QtQuick 2.11
import QtQuick.Layouts 1.2
import QtQuick.Window 2.2
import org.kde.kirigami 2.11
import QtGraphicalEffects 1.0
import QtQuick.Templates 2.0 as T2
import "private"
import "../private"

/**
 * An overlay sheet that covers the current Page content.
 * Its contents can be scrolled up or down, scrolling all the way up or
 * all the way down, dismisses it.
 * Use this for big, modal dialogs or information display, that can't be
 * logically done as a new separate Page, even if potentially
 * are taller than the screen space.
 * @inherits: QtQuick.QtObject
 */
QtObject {
    id: root

    Theme.colorSet: Theme.View
    Theme.inherit: false

    /**
     * contentItem: Item
     * This property holds the visual content item.
     *
     * Note: The content item is automatically resized inside the
     * padding of the control.
     * Conversely, the Sheet will be sized based on the size hints
     * of the contentItem, so if you need a custom size sheet,
     * redefine contentWidth and contentHeight of your contentItem
     */
    default property Item contentItem

    /**
     * sheetOpen: bool
     * If true the sheet is open showing the contents of the OverlaySheet
     * component.
     */
    property bool sheetOpen

    /**
     * leftPadding: int
     * default contents padding at left
     */
    property int leftPadding: Units.gridUnit

    /**
     * topPadding: int
     * default contents padding at top
     */
    property int topPadding: Units.gridUnit

    /**
     * rightPadding: int
     * default contents padding at right
     */
    property int rightPadding: Units.gridUnit

    /**
     * bottomPadding: int
     * default contents padding at bottom
     */
    property int bottomPadding: Units.gridUnit

    /**
     * header: Item
     * an optional item which will be used as the sheet's header,
     * always kept on screen
     * @since 5.43
     */
    property Item header

    /**
     * header: Item
     * an optional item which will be used as the sheet's footer,
     * always kept on screen
     * @since 5.43
     */
    property Item footer
    /**
     * background: Item
     * This property holds the background item.
     *
     * Note: If the background item has no explicit size specified,
     * it automatically follows the control's size.
     * In most cases, there is no need to specify width or
     * height for a background item.
     */
    property Item background

    /**
     * showCloseButton: bool
     * whether to show the close button in the top-right corner
     * @since 5.44
     */
    property alias showCloseButton: closeIcon.visible

    property Item parent


    function open() {
        openAnimation.running = true;
        root.sheetOpen = true;
        mainItem.visible = true;
    }

    function close() {
        closeAnimation.running = true;
    }

    onBackgroundChanged: {
        background.parent = contentLayout.parent;
        background.anchors.fill = contentLayout;
        background.z = -1;
    }
    onContentItemChanged: {
        if (contentItem instanceof Flickable) {
            scrollView.flickableItem = contentItem;
            contentItem.parent = scrollView;
            contentItem.anchors.fill = scrollView;
            scrollView.contentItem = contentItem;
        } else {
            if (!scrollView.flickableItem || scrollView.flickableItem == scrollView.contentItem) {
                scrollView.flickableItem = flickableComponent.createObject(scrollView);
            }

            contentItem.parent = contentItemParent;
            flickableContents.parent = scrollView.flickableItem.contentItem;
            scrollView.contentItem = flickableContents;
            contentItem.anchors.left = contentItemParent.left;
            contentItem.anchors.right = contentItemParent.right;
        }
        scrollView.flickableItem.interactive = false;
        scrollView.flickableItem.flickableDirection = Flickable.VerticalFlick;
    }
    onSheetOpenChanged: {
        if (sheetOpen) {
            open();
        } else {
            close();
            Qt.inputMethod.hide();
        }
    }
    onHeaderChanged: {
        header.parent = headerParent;
        header.anchors.fill = headerParent;

        //TODO: special case for actual ListViews
    }
    onFooterChanged: {
        footer.parent = footerParent;
        footer.anchors.fill = footerParent;
    }

    Component.onCompleted: {
        if (!root.parent && typeof applicationWindow !== "undefined") {
            root.parent = applicationWindow().overlay
        }
    }

    readonly property Item rootItem: MouseArea {
        id: mainItem
        Theme.colorSet: root.Theme.colorSet
        Theme.inherit: root.Theme.inherit
        //we want to be over any possible OverlayDrawers, including handles
        parent: {
            if (root.parent && root.parent.ColumnView.view && (root.parent.ColumnView.view == root.parent || root.parent.ColumnView.view == root.parent.parent)) {
                return root.parent.ColumnView.view.parent;
            } else if (root.parent && root.parent.overlay) {
                root.parent.overlay;
            } else {
                return root.parent;
            }
        }

        anchors.fill: parent

        z: 9998
        visible: false
        drag.filterChildren: true
        hoverEnabled: true
        clip: true

        onClicked: {
            var pos = mapToItem(flickableContents, mouse.x, mouse.y);
            if (!flickableContents.contains(pos)) {
                root.close();
            }
        }

        readonly property int contentItemPreferredWidth: root.contentItem.Layout.preferredWidth > 0 ? root.contentItem.Layout.preferredWidth : root.contentItem.implicitWidth

        readonly property int contentItemMaximumWidth: width > Units.gridUnit * 30 ? width * 0.95 : width

        property bool ownSizeUpdate: false
        function updateContentWidth() {return;
            if (!contentItem.contentItem) {
                return;
            }

            var newWidth = Math.min(contentItemMaximumWidth, Math.max(mainItem.width/2, Math.min(mainItem.width, mainItem.contentItemPreferredWidth)));

            if (scrollView.verticalScrollBar && scrollView.verticalScrollBar.interactive) {
                newWidth -= scrollView.verticalScrollBar.width;
            }

            ownSizeUpdate = true;
            contentItem.contentItem.x = (mainItem.width - newWidth)/2
            contentItem.contentItem.width = newWidth;
            ownSizeUpdate = false;
        }
        onContentItemMaximumWidthChanged: updateContentWidth()
        onWidthChanged: updateContentWidth()
        Connections {
            target: typeof contentItem.contentItem === "undefined" ? null : contentItem.contentItem
            onWidthChanged: {
                if (!mainItem.ownSizeUpdate) {
                    mainItem.updateContentWidth();
                }
            }
        }
        onHeightChanged: {
            var focusItem;

            focusItem = Window.activeFocusItem;

            if (!focusItem) {
                return;
            }

            //NOTE: there is no function to know if an item is descended from another,
            //so we have to walk the parent hierarchy by hand
            var isDescendent = false;
            var candidate = focusItem.parent;
            while (candidate) {
                if (candidate === root) {
                    isDescendent = true;
                    break;
                }
                candidate = candidate.parent;
            }
            if (!isDescendent) {
                return;
            }

            var cursorY = 0;
            if (focusItem.cursorPosition !== undefined) {
                cursorY = focusItem.positionToRectangle(focusItem.cursorPosition).y;
            }

            
            var pos = focusItem.mapToItem(flickableContents, 0, cursorY - Units.gridUnit*3);
            //focused item already visible? add some margin for the space of the action buttons
            if (pos.y >= scrollView.flickableItem.contentY && pos.y <= scrollView.flickableItem.contentY + scrollView.flickableItem.height - Units.gridUnit * 8) {
                return;
            }
            scrollView.flickableItem.contentY = pos.y;
        }

        ParallelAnimation {
            id: openAnimation 
            property int margins: Units.gridUnit * 5
            NumberAnimation {
                target: outerFlickable
                properties: "contentY"
                from: -outerFlickable.height
                to: 0
                duration: Units.longDuration
                easing.type: Easing.OutQuad
            }
            OpacityAnimator {
                target: mainItem
                from: 0
                to: 1
                duration: Units.longDuration
                easing.type: Easing.InQuad
            }
        }

        NumberAnimation {
            id: resetAnimation
            target: outerFlickable
            properties: "contentY"
            from: outerFlickable.contentY
            to: scrollView.flickableItem.atYEnd ? outerFlickable.contentHeight - outerFlickable.height + outerFlickable.topEmptyArea + headerItem.height + footerItem.height : 0
            duration: Units.longDuration
            easing.type: Easing.OutQuad
        }

        SequentialAnimation {
            id: closeAnimation
            ParallelAnimation {
                NumberAnimation {id: bah
                    target: outerFlickable
                    properties: "contentY"
                    to: scrollView.flickableItem.visibleArea.yPosition < (1 - scrollView.flickableItem.visibleArea.heightRatio)/2 ? -mainItem.height : outerFlickable.contentHeight
                    duration: Units.longDuration
                    easing.type: Easing.InQuad
                }
                OpacityAnimator {
                    target: mainItem
                    from: 1
                    to: 0
                    duration: Units.longDuration
                    easing.type: Easing.InQuad
                }
            }
            ScriptAction {
                script: {
                    scrollView.flickableItem.contentY = -mainItem.height;
                    mainItem.visible = root.sheetOpen = false;
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.6 * Math.min(
                (Math.min(scrollView.flickableItem.contentY + scrollView.flickableItem.height, scrollView.flickableItem.height) / scrollView.flickableItem.height),
                (2 + (scrollView.flickableItem.contentHeight - scrollView.flickableItem.contentY - scrollView.flickableItem.topMargin - scrollView.flickableItem.bottomMargin)/scrollView.flickableItem.height))
        }

        FocusScope {
            id: flickableContents
            //anchors.horizontalCenter: parent.horizontalCenter
           // x: (mainItem.width - width) / 2

            readonly property real listHeaderHeight: scrollView.flickableItem && root.contentItem.headerItem ? root.contentItem.headerItem.height : 0

            y: (scrollView.contentItem != flickableContents ? -scrollView.flickableItem.contentY - listHeaderHeight  - (headerItem.visible ? headerItem.height : 0): 0)

            width: mainItem.contentItemPreferredWidth <= 0 ? mainItem.width : Math.max(mainItem.width/2, Math.min(mainItem.contentItemMaximumWidth, mainItem.contentItemPreferredWidth))

            height: scrollView.contentItem == flickableContents ? (root.contentItem.height + topPadding + bottomPadding) + (headerItem.visible ? headerItem.height : 0) + (footerItem.visible ? footerItem.height : 0) : 0
            Connections {
                target: enabled ? flickableContents.Window.activeFocusItem : null
                enabled: flickableContents.focus && flickableContents.Window.activeFocusItem && flickableContents.Window.activeFocusItem.hasOwnProperty("text")
                onTextChanged: {
                    if (Qt.inputMethod.cursorRectangle.y + Qt.inputMethod.cursorRectangle.height > mainItem.Window.height) {
                        scrollView.flickableItem.contentY += (Qt.inputMethod.cursorRectangle.y + Qt.inputMethod.cursorRectangle.height) - mainItem.Window.height
                    }
                }
            }

            Item {
                id: contentItemParent
                anchors {
                    fill: parent
                    leftMargin: leftPadding
                    topMargin: topPadding + (headerItem.visible ? headerItem.height : 0)
                    rightMargin: rightPadding + (scrollView.verticalScrollBar && scrollView.verticalScrollBar.interactive ? scrollView.verticalScrollBar.width : 0)
                    bottomMargin: bottomPadding + (footerItem.visible ? footerItem.height : 0)
                }
            }
        }

        Connections {
            target: scrollView.flickableItem
            onContentHeightChanged: {
                if (openAnimation.running) {
                    openAnimation.running = false;
                    open();
                }
            }
        }

        Flickable {
            id: outerFlickable
            anchors.fill: parent
            contentWidth: width
            topMargin: height
            bottomMargin: height
            contentHeight: Math.max(height+1, scrollView.flickableItem.contentHeight)

            readonly property int topEmptyArea: Math.max(height-scrollView.flickableItem.contentHeight, Units.gridUnit * 3)
  
            property int oldContentY: NaN
            property bool lastMovementWasDown: false
            onContentYChanged: {
                let startPos = -scrollView.flickableItem.topMargin;
                let pos = contentY - topEmptyArea;
                let endPos = scrollView.flickableItem.contentHeight - scrollView.flickableItem.height + scrollView.flickableItem.bottomMargin;

                if (endPos - pos > 0) {
                    contentLayout.y = Math.max(0, scrollView.flickableItem.topMargin - pos);
                } else if (scrollView.flickableItem.topMargin - pos < 0) {
                    contentLayout.y = endPos - pos;
                }

                scrollView.flickableItem.contentY = Math.max(
                    startPos, Math.min(pos, endPos));

                lastMovementWasDown = contentY < oldContentY;
                oldContentY = contentY;
            }

            onFlickEnded: {
                if (openAnimation.running || closeAnimation.running) {
                    return;
                }
                if (scrollView.flickableItem.atYBeginning ||scrollView.flickableItem.atYEnd) {
                    resetAnimation.restart();
                }
            }

            onDraggingChanged: {
                if (dragging) {
                    return;
                }

                // close
                if (scrollView.flickableItem.atYBeginning) {
                    if (contentY < -Units.gridUnit * 4 && lastMovementWasDown) {
                        closeAnimation.restart();
                    } else {
                        resetAnimation.restart();
                    }
                }

                if (scrollView.flickableItem.atYEnd) {
                    if (contentY > contentHeight - height - Units.gridUnit * 4 && !lastMovementWasDown) {
                        closeAnimation.restart();
                    } else {
                        resetAnimation.restart();
                    }
                }
            }

            ColumnLayout {
                id: contentLayout
                spacing: 0
                // Its events should be filtered but not scrolled
                parent: outerFlickable
                anchors.horizontalCenter: parent.horizontalCenter
                width: mainItem.contentItemPreferredWidth <= 0 ? mainItem.width : Math.max(mainItem.width/2, Math.min(mainItem.contentItemMaximumWidth, mainItem.contentItemPreferredWidth))
                height: Math.min(implicitHeight, parent.height)

                Icon {
                    id: closeIcon
                    anchors {
                        right: contentLayout.right
                        margins: Units.smallSpacing
                        top: contentLayout.top
                    }
                    parent: outerFlickable
                    z: 3
                    visible: !Settings.isMobile
                    width: Units.iconSizes.smallMedium
                    height: width
                    source: closeMouseArea.containsMouse ? "window-close" : "window-close-symbolic"
                    active: closeMouseArea.containsMouse
                    MouseArea {
                        id: closeMouseArea
                        hoverEnabled: true
                        anchors.fill: parent
                        onClicked: root.close();
                    }
                }

                Rectangle {
                    id: headerItem
                    Layout.fillWidth: true
                    visible: root.header
                    implicitHeight: Math.max(headerParent.implicitHeight, closeIcon.height) + Units.smallSpacing * 2
                    color: Theme.backgroundColor
                    z: 2
                    Item {
                        id: headerParent
                        implicitHeight: header ? header.implicitHeight : 0
                        anchors {
                            fill: parent
                            margins: Units.smallSpacing
                            rightMargin: closeIcon.width + Units.smallSpacing
                        }
                    }
                    
                    EdgeShadow {
                        z: -2
                        edge: Qt.TopEdge
                        anchors {
                            right: parent.right
                            left: parent.left
                            top: parent.bottom
                        }

                        opacity: parent.y == 0 ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Units.longDuration
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }
        
                Item {
                    id: scrollView

                    property Item contentItem
                    property Flickable flickableItem

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    implicitHeight: flickableItem.contentHeight

                    Component {
                        id: flickableComponent
                        Flickable {
                            anchors.fill: parent
                            parent: scrollView
                            contentWidth:width
                            contentHeight: flickableContents.height
                        }
                    }
                }
                
                Rectangle {
                    id: footerItem
                    Layout.fillWidth: true
                   // x: flickableContents.x
                    visible: root.footer
                    implicitHeight: footerParent.implicitHeight + Units.smallSpacing * 2 + extraMargin
                    color: Theme.backgroundColor

                    //Show an extra margin when:
                    //* the application is in mobile mode (no toolbarapplicationheader)
                    //* the bottom screen controls are visible
                    //* the sheet is displayed *under* the controls
                    property int extraMargin: (!root.parent ||
                        typeof applicationWindow === "undefined" ||
                        (root.parent === applicationWindow().overlay) ||
                        !applicationWindow().controlsVisible ||
                        (applicationWindow().pageStack && applicationWindow().pageStack.globalToolBar && applicationWindow().pageStack.globalToolBar.actualStyle === ApplicationHeaderStyle.ToolBar) ||
                        (applicationWindow().header && applicationWindow().header.toString().indexOf("ToolBarApplicationHeader") === 0))
                            ? 0 : Units.gridUnit * 3

                    z: 2
                    Item {
                        id: footerParent
                        implicitHeight: footer ? footer.implicitHeight : 0
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: Units.smallSpacing
                        }
                    }

                    EdgeShadow {
                        z: -2
                        edge: Qt.BottomEdge
                        anchors {
                            right: parent.right
                            left: parent.left
                            bottom: parent.top
                        }

                        opacity: parent.y + parent.height < mainItem.height ? 0 : 1

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Units.longDuration
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }
                }
            }
        }
    }
}
