#include "AdBlockInterceptor.h"

#include "AdBlockManager.h"

AdBlockInterceptor::AdBlockInterceptor(AdBlockManager *manager)
    : QWebEngineUrlRequestInterceptor(manager)
    , m_manager(manager)
{
}

void AdBlockInterceptor::interceptRequest(QWebEngineUrlRequestInfo &info)
{
    if (m_manager)
        m_manager->interceptRequest(info);
}
