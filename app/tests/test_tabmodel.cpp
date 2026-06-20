#include <QtTest/QAbstractItemModelTester>
#include <QtTest/QSignalSpy>
#include <QtTest/QTest>

#include "TabModel.h"
#include "BookmarkModel.h"
#include "HistoryModel.h"
#include "QuickLinkModel.h"
#include "WorkspaceModel.h"

#include <QSettings>
#include <QStandardPaths>

class TabModelTest : public QObject
{
    Q_OBJECT

private slots:
    void init()
    {
        QStandardPaths::setTestModeEnabled(true);
        QCoreApplication::setOrganizationName(QStringLiteral("FilkaTests"));
        QCoreApplication::setApplicationName(QStringLiteral("model-tests"));
        QSettings settings;
        settings.clear();
        settings.sync();
    }

    void addAndCloseKeepsOneTab()
    {
        TabModel tabs;

        QCOMPARE(tabs.addTab(QUrl(QStringLiteral("https://example.com"))), 0);
        QCOMPARE(tabs.rowCount(), 1);
        QCOMPARE(tabs.activeIndex(), 0);

        tabs.closeTab(0);
        QCOMPARE(tabs.rowCount(), 1);
        QCOMPARE(tabs.activeIndex(), 0);
        QCOMPARE(tabs.tabUrls(), QStringList{QStringLiteral("about:blank")});
    }

    void duplicateAndReopenClosedTab()
    {
        TabModel tabs;
        tabs.addTab(QUrl(QStringLiteral("https://example.com")));

        QCOMPARE(tabs.duplicateTab(0), 1);
        QCOMPARE(tabs.rowCount(), 2);
        QCOMPARE(tabs.activeIndex(), 1);

        tabs.closeTab(1);
        QCOMPARE(tabs.rowCount(), 1);
        QVERIFY(tabs.hasClosedTabs());

        QCOMPARE(tabs.reopenClosedTab(), 1);
        QCOMPARE(tabs.rowCount(), 2);
        QCOMPARE(tabs.activeIndex(), 1);
        QCOMPARE(tabs.tabUrls().at(1), QStringLiteral("https://example.com"));
    }

    void moveTabKeepsActiveTab()
    {
        TabModel tabs;
        tabs.addTab(QUrl(QStringLiteral("https://one.example")));
        tabs.addTab(QUrl(QStringLiteral("https://two.example")));
        tabs.addTab(QUrl(QStringLiteral("https://three.example")));

        QCOMPARE(tabs.activeIndex(), 2);
        QSignalSpy changedSpy(&tabs, &TabModel::changed);
        tabs.moveTab(2, 0);

        QCOMPARE(tabs.activeIndex(), 0);
        QCOMPARE(tabs.tabUrls().at(0), QStringLiteral("https://three.example"));
        QCOMPARE(changedSpy.size(), 1);
    }

    void historyRevisitMovesRowSafely()
    {
        HistoryModel history;
        QAbstractItemModelTester tester(&history, QAbstractItemModelTester::FailureReportingMode::QtTest);

        history.clear();
        history.recordVisit(QUrl(QStringLiteral("https://one.example")), QStringLiteral("One"));
        history.recordVisit(QUrl(QStringLiteral("https://two.example")), QStringLiteral("Two"));
        history.recordVisit(QUrl(QStringLiteral("https://three.example")), QStringLiteral("Three"));

        QCOMPARE(history.rowCount(), 3);
        QCOMPARE(history.data(history.index(2, 0), HistoryModel::UrlRole).toString(),
                 QStringLiteral("https://one.example"));

        history.recordVisit(QUrl(QStringLiteral("https://one.example")), QString());

        QCOMPARE(history.rowCount(), 3);
        QCOMPARE(history.data(history.index(0, 0), HistoryModel::UrlRole).toString(),
                 QStringLiteral("https://one.example"));
        QCOMPARE(history.data(history.index(0, 0), HistoryModel::TitleRole).toString(),
                 QStringLiteral("One"));
        QCOMPARE(history.data(history.index(0, 0), HistoryModel::VisitCountRole).toInt(), 2);
    }

    void workspaceResetUsesSingleResetSignal()
    {
        WorkspaceModel workspaces;
        QAbstractItemModelTester tester(&workspaces, QAbstractItemModelTester::FailureReportingMode::QtTest);

        const int extra = workspaces.addWorkspace(QStringLiteral("Extra"));
        QCOMPARE(workspaces.activeIndex(), extra);
        QSignalSpy activeNameSpy(&workspaces, &WorkspaceModel::activeNameChanged);

        workspaces.resetWorkspaces();

        QCOMPARE(workspaces.rowCount(), 4);
        QCOMPARE(workspaces.activeIndex(), 0);
        QCOMPARE(workspaces.activeName(), QStringLiteral("Работа"));
        QVERIFY(!activeNameSpy.isEmpty());
    }

    void workspaceResetKeepsAutosave()
    {
        WorkspaceModel workspaces;
        workspaces.resetWorkspaces();

        TabModel *tabs = workspaces.activeTabs();
        QVERIFY(tabs);
        tabs->addTab(QUrl(QStringLiteral("https://after-reset.example")));

        QTest::qWait(950);

        QSettings store;
        const int workspaceCount = store.beginReadArray(QStringLiteral("session/workspaces"));
        QVERIFY(workspaceCount > 0);
        store.setArrayIndex(0);
        const QStringList urls = store.value(QStringLiteral("tabs")).toStringList();
        store.endArray();
        QVERIFY(urls.contains(QStringLiteral("https://after-reset.example")));
    }

    void bookmarkToggleRejectsInvalidUrl()
    {
        BookmarkModel bookmarks;
        QAbstractItemModelTester tester(&bookmarks, QAbstractItemModelTester::FailureReportingMode::QtTest);
        bookmarks.clear();

        QVERIFY(!bookmarks.toggle(QUrl(QStringLiteral("about:blank")), QStringLiteral("Blank")));
        QVERIFY(!bookmarks.toggle(QUrl(QStringLiteral("file:///tmp/local.html")), QStringLiteral("Local")));
        QCOMPARE(bookmarks.rowCount(), 0);
    }


    void bookmarkInsertAtRestoresDeletedPosition()
    {
        BookmarkModel bookmarks;
        QAbstractItemModelTester tester(&bookmarks, QAbstractItemModelTester::FailureReportingMode::QtTest);
        bookmarks.clear();

        bookmarks.add(QUrl(QStringLiteral("https://three.example")), QStringLiteral("Three"));
        bookmarks.add(QUrl(QStringLiteral("https://two.example")), QStringLiteral("Two"));
        bookmarks.add(QUrl(QStringLiteral("https://one.example")), QStringLiteral("One"));
        QCOMPARE(bookmarks.rowCount(), 3);

        bookmarks.removeAt(1);
        QCOMPARE(bookmarks.rowCount(), 2);
        QCOMPARE(bookmarks.data(bookmarks.index(1, 0), BookmarkModel::UrlRole).toString(),
                 QStringLiteral("https://three.example"));

        bookmarks.insertAt(1, QUrl(QStringLiteral("https://two.example")), QStringLiteral("Two"));
        QCOMPARE(bookmarks.rowCount(), 3);
        QCOMPARE(bookmarks.data(bookmarks.index(0, 0), BookmarkModel::UrlRole).toString(),
                 QStringLiteral("https://one.example"));
        QCOMPARE(bookmarks.data(bookmarks.index(1, 0), BookmarkModel::UrlRole).toString(),
                 QStringLiteral("https://two.example"));
        QCOMPARE(bookmarks.data(bookmarks.index(2, 0), BookmarkModel::UrlRole).toString(),
                 QStringLiteral("https://three.example"));

        bookmarks.clear();
    }

    void restoreClampsActiveIndex()
    {
        TabModel tabs;
        tabs.restore(QStringList{
            QStringLiteral("https://one.example"),
            QStringLiteral("https://two.example"),
        }, 42);

        QCOMPARE(tabs.rowCount(), 2);
        QCOMPARE(tabs.activeIndex(), 1);
    }

    void quickLinksInstallDefaults()
    {
        QuickLinkModel links;

        QCOMPARE(links.rowCount(), 4);
        const QVariantList all = links.search(QString(), 10);
        QCOMPARE(all.size(), 4);
        QCOMPARE(all.first().toMap().value(QStringLiteral("title")).toString(),
                 QStringLiteral("YouTube"));
    }

    void quickLinksAddUpdateMoveRemove()
    {
        QuickLinkModel links;
        links.add(QStringLiteral("Qt"), QUrl(QStringLiteral("https://qt.io")));

        QCOMPARE(links.rowCount(), 5);
        QCOMPARE(links.search(QStringLiteral("qt"), 10).first().toMap()
                     .value(QStringLiteral("url")).toString(),
                 QStringLiteral("https://qt.io"));

        links.update(4, QStringLiteral("Qt Docs"), QUrl(QStringLiteral("https://doc.qt.io")));
        QCOMPARE(links.search(QStringLiteral("docs"), 10).first().toMap()
                     .value(QStringLiteral("title")).toString(),
                 QStringLiteral("Qt Docs"));

        links.move(4, 0);
        QCOMPARE(links.search(QString(), 10).first().toMap()
                     .value(QStringLiteral("title")).toString(),
                 QStringLiteral("Qt Docs"));

        links.remove(0);
        QCOMPARE(links.rowCount(), 4);
    }
};

QTEST_GUILESS_MAIN(TabModelTest)
#include "test_tabmodel.moc"
