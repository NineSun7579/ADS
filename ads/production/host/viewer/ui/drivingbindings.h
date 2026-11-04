#pragma once
#include <QMap>
#include <QVariant>
#include "../status_bar.h"

// Presentation only: selections are not permission or vehicle motion evidence.
namespace driving_ui {
inline QString ink(vehicle_action::Color color) {
    switch(color) {
    case vehicle_action::Color::Red:return QStringLiteral("#ef4444");
    case vehicle_action::Color::Yellow:return QStringLiteral("#f59e0b");
    case vehicle_action::Color::Green:return QStringLiteral("#22c55e");
    default:return QStringLiteral("#7c899d");
    }
}
inline QMap<QString,QVariant> bindings(const vehicle_action::Result& result,
    bool requested,int assumedLane,int changeRequest,bool showIntent,qint64 now,
    int feedbackControl=-1,qint64 feedbackUntil=0,
    bool driveSelectionMade=false,bool laneSelectionMade=false,
    const QString& pressedControl=QString(),
    const QMap<QString,QVariant>& predictionStates=QMap<QString,QVariant>()) {
    Q_UNUSED(result);
    Q_UNUSED(changeRequest);
    Q_UNUSED(feedbackControl);
    Q_UNUSED(feedbackUntil);
    QMap<QString,QVariant> values;
    const QString keys[]={QStringLiteral("ui.predictionLeft"),QStringLiteral("ui.predictionStraight"),
        QStringLiteral("ui.predictionRight"),QStringLiteral("ui.predictionViolation"),
        QStringLiteral("ui.predictionEmergency"),QStringLiteral("ui.predictionStop")};
    for(int i=0;i<6;++i) {
        // Explicit prediction output selects a variant. Internal FSM state,
        // action and diagnostic cards must not manufacture a prediction.
        QString state=predictionStates.value(keys[i],QStringLiteral("normal")).toString();
        if(predictionStates.value(keys[i]+QStringLiteral(".blink"),false).toBool()&&
           !status_bar::blinkPhase(now))state=QStringLiteral("normal");
        if((!showIntent&&i<3)||(state!=QStringLiteral("active")&&state!=QStringLiteral("warning")))
            state=QStringLiteral("normal");
        values[keys[i]]=state;
        values[keys[i]+QStringLiteral(".ink")]=ink(state==QStringLiteral("active")?
            vehicle_action::Color::Green:state==QStringLiteral("warning")?
            vehicle_action::Color::Red:vehicle_action::Color::Gray);
    }
    const QString controls[]={QStringLiteral("ui.drive"),QStringLiteral("ui.stop"),
        QStringLiteral("ui.left"),QStringLiteral("ui.straight"),QStringLiteral("ui.right")};
    for(int i=0;i<5;++i) {
        const bool active=i<2?(pressedControl==(i==0?QStringLiteral("drive-go"):QStringLiteral("drive-stop"))):
            (laneSelectionMade&&assumedLane>=-1&&assumedLane<=1&&i==assumedLane+3);
        values[controls[i]]=active?QStringLiteral("active"):QStringLiteral("normal");
        values[controls[i]+QStringLiteral(".ink")]=ink(active?
            (i==1?vehicle_action::Color::Red:vehicle_action::Color::Green):vehicle_action::Color::Gray);
    }
    const QString changes[]={QStringLiteral("ui.changeLeft"),QStringLiteral("ui.changeRight")};
    for(int i=0;i<2;++i) {
        const bool active=pressedControl==(i==0?QStringLiteral("drive-change-left"):QStringLiteral("drive-change-right"));
        values[changes[i]]=active?QStringLiteral("active"):QStringLiteral("normal");
        values[changes[i]+QStringLiteral(".ink")]=ink(active?vehicle_action::Color::Green:vehicle_action::Color::Gray);
    }
    return values;
}
}
