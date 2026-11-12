.pragma library

function normalize(value) {
    return (value || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "")
}

function applications(entries, query, excludedIds) {
    const terms = normalize(query).trim().split(/\s+/).filter(Boolean)
    return entries.filter(entry => !entry.noDisplay && !entry.runInTerminal
        && !excludedIds.includes(entry.id)).map(entry => {
        const name = normalize(entry.name)
        const metadata = normalize([entry.genericName, ...(entry.keywords || [])].join(" "))
        let score = 0
        for (const term of terms) {
            if (name === term) score += 0
            else if (name.startsWith(term)) score += 1
            else if (name.includes(term)) score += 2
            else if (metadata.includes(term)) score += 3
            else return null
        }
        return { entry, score }
    }).filter(Boolean).sort((a, b) => a.score - b.score
        || a.entry.name.localeCompare(b.entry.name)
        || a.entry.id.localeCompare(b.entry.id)).map(result => result.entry)
}
