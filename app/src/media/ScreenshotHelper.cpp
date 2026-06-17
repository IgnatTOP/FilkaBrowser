#include "ScreenshotHelper.h"

#include <QClipboard>
#include <QDesktopServices>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QImage>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QUrl>

ScreenshotHelper::ScreenshotHelper(QObject *parent) : QObject(parent) {}

QString ScreenshotHelper::sanitizedTitle(const QString &title)
{
    QString clean = title.trimmed();
    if (clean.isEmpty())
        clean = QStringLiteral("Filka");
    clean.replace(QRegularExpression(QStringLiteral(R"([\/\\:*?"<>|]+)")), QStringLiteral("_"));
    clean.replace(QRegularExpression(QStringLiteral(R"(\s+)")), QStringLiteral(" "));
    return clean.left(80).trimmed();
}

QString ScreenshotHelper::makePath(const QString &directory, const QString &title) const
{
    QString dir = directory.trimmed();
    if (dir.isEmpty())
        dir = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    if (dir.isEmpty())
        dir = QDir::homePath();

    QDir().mkpath(dir);
    const QString stamp = QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd_HHmmss"));
    return QDir(dir).filePath(QStringLiteral("%1_%2.png").arg(sanitizedTitle(title), stamp));
}

QString ScreenshotHelper::temporaryPath() const
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    if (dir.isEmpty())
        dir = QDir::tempPath();
    QDir().mkpath(dir);
    const QString stamp = QString::number(QDateTime::currentMSecsSinceEpoch());
    return QDir(dir).filePath(QStringLiteral("filka_screenshot_%1.png").arg(stamp));
}

bool ScreenshotHelper::cropImageFile(const QString &sourcePath, const QString &targetPath,
                                     const QRectF &logicalRect, const QSizeF &logicalSize) const
{
    QImage image(sourcePath);
    if (image.isNull())
        return false;

    QRect cropRect;
    if (logicalRect.isValid() && logicalSize.width() > 0 && logicalSize.height() > 0) {
        const qreal sx = image.width() / logicalSize.width();
        const qreal sy = image.height() / logicalSize.height();
        cropRect = QRect(qRound(logicalRect.x() * sx),
                         qRound(logicalRect.y() * sy),
                         qRound(logicalRect.width() * sx),
                         qRound(logicalRect.height() * sy));
    } else {
        cropRect = image.rect();
    }

    cropRect = cropRect.normalized().intersected(image.rect());
    if (cropRect.width() < 1 || cropRect.height() < 1)
        return false;

    QDir().mkpath(QFileInfo(targetPath).absolutePath());
    return image.copy(cropRect).save(targetPath, "PNG");
}

bool ScreenshotHelper::copyImageFile(const QString &path) const
{
    QImage image(path);
    if (image.isNull())
        return false;
    if (QClipboard *clipboard = QGuiApplication::clipboard()) {
        clipboard->setImage(image);
        return true;
    }
    return false;
}

void ScreenshotHelper::revealFile(const QString &path) const
{
    if (path.trimmed().isEmpty())
        return;
    QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}
