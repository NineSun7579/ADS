#pragma once
#if defined(ADS_ENABLE_TEST_INPUTS) && ADS_ENABLE_TEST_INPUTS
#error "ADS production forbids simulated, replay and remote inputs"
#endif
#define ADS_ENABLE_TEST_INPUTS 0
#ifndef ADS_PRODUCTION_LIVE_ONLY
#error "Build with ads-production.pro"
#endif
