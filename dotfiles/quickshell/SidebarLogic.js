.pragma library

// Return only exposed vertical edge segments, including staggered monitor layouts.
function edgeSegments(screens) {
    const result = []
    for (const screen of screens) {
        for (const side of ["left", "right"]) {
            const boundary = side === "left" ? screen.x : screen.x + screen.width
            let spans = [[screen.y, screen.y + screen.height]]
            for (const other of screens) {
                if (other.name === screen.name)
                    continue
                const covered = side === "left"
                    ? other.x < boundary && other.x + other.width >= boundary
                    : other.x <= boundary && other.x + other.width > boundary
                if (!covered)
                    continue
                const top = other.y
                const bottom = other.y + other.height
                const remaining = []
                for (const span of spans) {
                    if (bottom <= span[0] || top >= span[1]) {
                        remaining.push(span)
                    } else {
                        if (top > span[0]) remaining.push([span[0], top])
                        if (bottom < span[1]) remaining.push([bottom, span[1]])
                    }
                }
                spans = remaining
            }
            for (const span of spans) {
                result.push({ screen: screen, side: side,
                    top: span[0] - screen.y, height: span[1] - span[0] })
            }
        }
    }
    return result
}

function duration(seconds) {
    if (!Number.isFinite(seconds) || seconds <= 0)
        return ""
    const minutes = Math.max(1, Math.round(seconds / 60))
    const hours = Math.floor(minutes / 60)
    return hours > 0 ? hours + " h " + (minutes % 60) + " min" : minutes + " min"
}
