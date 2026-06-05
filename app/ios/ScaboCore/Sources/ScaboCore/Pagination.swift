//
//  Pagination.swift
//  ScaboCore
//
//  Slices a layout's flat segment stream into pages for the native reading view.
//  Faithful translation of `app/src/rendering/pagination.ts`.
//
//  v1 paginates by a fixed segment count: simple, deterministic, layout-aware by
//  virtue of being applied to the per-layout stream. The real page-size heuristic
//  (segments fitting the viewport at the active font size, with text measurement
//  from the native side) is a polish reserved for the post-Mac view.
//
//  Language difference (documented). The TS throws a plain `Error` on a
//  non-positive page size, caught by its test with `toThrow`. Here `paginate`
//  is a Swift `throws` function raising `PaginationError.nonPositivePageSize`,
//  which XCTest checks with `XCTAssertThrowsError`. The message contains the same
//  "segmentsPerPage must be > 0" wording the oracle matches.
//

import Foundation

/// Heuristic default. Refined later with on-device measurements.
public let DEFAULT_SEGMENTS_PER_PAGE = 20

/// Failure raised by `paginate` for an invalid page size.
public enum PaginationError: Error, Equatable, Sendable, CustomStringConvertible {
    case nonPositivePageSize(Int)

    public var description: String {
        switch self {
        case .nonPositivePageSize(let value):
            return "segmentsPerPage must be > 0, got \(value)"
        }
    }
}

public func paginate(
    _ segments: [ContentSegment],
    _ segmentsPerPage: Int = DEFAULT_SEGMENTS_PER_PAGE
) throws -> PaginatedContent {
    if segmentsPerPage <= 0 {
        throw PaginationError.nonPositivePageSize(segmentsPerPage)
    }
    var pages: [ContentPage] = []
    var i = 0
    while i < segments.count {
        let end = Swift.min(i + segmentsPerPage, segments.count)
        pages.append(ContentPage(
            pageNumber: i / segmentsPerPage + 1,
            segments: Array(segments[i..<end])
        ))
        i += segmentsPerPage
    }
    if pages.isEmpty {
        pages.append(ContentPage(pageNumber: 1, segments: []))
    }
    return PaginatedContent(pages: pages, totalSegments: segments.count)
}
