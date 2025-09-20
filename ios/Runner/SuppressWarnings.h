//
//  SuppressWarnings.h
//  Runner
//
//  Created to suppress third-party package warnings
//

#ifndef SuppressWarnings_h
#define SuppressWarnings_h

// Suppress all deprecation warnings from third-party packages
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// Suppress unused variable warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"

// Suppress implicit coercion warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wimplicit-int-conversion"

// Suppress property attribute warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-property-no-attribute"

// Suppress protocol conformance warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wprotocol"

// Suppress parameter type conflict warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincompatible-pointer-types"

// Suppress unused parameter warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"

// Suppress function declaration warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wstrict-prototypes"

// Suppress uninitialized variable warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wuninitialized"

// Suppress unused value warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-value"

// Suppress deprecated method implementation warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

// Suppress keyWindow deprecation warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// Suppress UTType deprecation warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// Suppress authorizationStatus deprecation warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// Suppress windows deprecation warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// Suppress subscriberCellularProvider deprecation warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// This file is included in the main target to suppress warnings from third-party packages
// that we cannot control directly

#endif /* SuppressWarnings_h */
