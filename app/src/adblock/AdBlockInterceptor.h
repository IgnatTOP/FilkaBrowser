#pragma once

#include <QtWebEngineCore/QWebEngineUrlRequestInterceptor>

class AdBlockManager;

class AdBlockInterceptor : public QWebEngineUrlRequestInterceptor
{
    Q_OBJECT

public:
    explicit AdBlockInterceptor(AdBlockManager *manager);

    void interceptRequest(QWebEngineUrlRequestInfo &info) override;

private:
    AdBlockManager *m_manager = nullptr;
};
