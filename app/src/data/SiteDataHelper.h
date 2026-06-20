#pragma once

#include <QObject>
#include <QVariantList>
#include <qqmlregistration.h>

class SiteDataHelper : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit SiteDataHelper(QObject *parent = nullptr);

    Q_INVOKABLE QVariantList permissionsForOrigin(QObject *profile, const QString &url) const;
    Q_INVOKABLE void clearPermissionsForOrigin(QObject *profile, const QString &url);
    Q_INVOKABLE void clearCookiesForOrigin(QObject *profile, const QString &url);
    Q_INVOKABLE QString originForUrl(const QString &url) const;
    Q_INVOKABLE bool isOffTheRecord(QObject *profile) const;
};
