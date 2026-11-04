include(detview.pro)
TARGET = ads-production-live
DEFINES += ADS_PRODUCTION_LIVE_ONLY=1
contains(CONFIG, runtime_ui_test): error("Production cannot build runtime_ui_test")
HEADERS += production_contract.h
