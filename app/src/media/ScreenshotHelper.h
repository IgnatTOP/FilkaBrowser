#pragma once

#include <QDateTime>
#include <QObject>
#include <QRectF>
#include <QSizeF>
#include <QString>
#include <qqmlregistration.h>

class ScreenshotHelper : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit ScreenshotHelper(QObject *parent = nullptr);

    Q_INVOKABLE QString makePath(const QString &directory, const QString &title) const;
    Q_INVOKABLE QString temporaryPath() const;
    Q_INVOKABLE bool cropImageFile(const QString &sourcePath, const QString &targetPath,
                                   const QRectF &logicalRect, const QSizeF &logicalSize) const;
    Q_INVOKABLE bool copyImageFile(const QString &path) const;
    Q_INVOKABLE void revealFile(const QString &path) const;

private:
    static QString sanitizedTitle(const QString &title);
};
