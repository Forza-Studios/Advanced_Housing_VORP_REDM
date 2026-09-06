// ===== COI Housing Manager — Dashboard Script =====

// Dummy data for the dashboard
const DUMMY_HOUSES = [
    { id: 1, name: "Valentine Cabin", location: "Valentine", price: 750, owner: "John Doe", status: "owned" },
    { id: 2, name: "Strawberry House", location: "Strawberry", price: 1200, owner: null, status: "available" },
    { id: 3, name: "Saint Denis Apartment", location: "Saint Denis", price: 2500, owner: "Jane Smith", status: "owned" },
    { id: 4, name: "Rhodes Ranch", location: "Rhodes", price: 1800, owner: null, status: "available" },
    { id: 5, name: "Colter Lodge", location: "Colter", price: 3000, owner: null, status: "available" },
    { id: 6, name: "Lagras Shack", location: "Lagras", price: 900, owner: "Mike Brown", status: "owned" },
    { id: 7, name: "Blackwater Manor", location: "Blackwater", price: 4200, owner: "Sarah Wilson", status: "owned" },
    { id: 8, name: "Tumbleweed Outpost", location: "Tumbleweed", price: 600, owner: null, status: "locked" },
];

const HOUSE_ICONS = ["🏚️", "🏠", "🏛️", "🏡", "🏔️", "🛖", "🏘️", "🌵"];

// Unique locations extracted from data
function getLocations(houses) {
    return [...new Set(houses.map(h => h.location))];
}

// Compute stats
function computeStats(houses) {
    const total = houses.length;
    const owned = houses.filter(h => h.status === "owned").length;
    const available = houses.filter(h => h.status === "available").length;
    const totalValue = houses.reduce((s, h) => s + h.price, 0);
    return { total, owned, available, totalValue };
}

// Format price
function fmt(n) {
    return "$" + n.toLocaleString();
}

// Build the full dashboard HTML
function buildDashboard(houses, filter = "all", search = "") {
    // Filter
    let filtered = houses;
    if (filter !== "all") {
        filtered = filtered.filter(h => h.location === filter);
    }
    if (search.trim()) {
        const q = search.toLowerCase();
        filtered = filtered.filter(h =>
            h.name.toLowerCase().includes(q) ||
            h.location.toLowerCase().includes(q) ||
            (h.owner && h.owner.toLowerCase().includes(q))
        );
    }

    const stats = computeStats(houses);
    const locations = getLocations(houses);

    return `
    <!-- Sidebar -->
    <div class="sidebar">
        <div class="sidebar-brand">
            <h2><span class="brand-icon">🏠</span> Housing</h2>
        </div>
        <nav class="sidebar-nav">
            <div class="nav-item active" data-page="houses">
                <span class="nav-icon">🏘️</span> Houses
            </div>
            <div class="nav-item" data-page="locations">
                <span class="nav-icon">📍</span> Locations
            </div>
            <div class="nav-item" data-page="owners">
                <span class="nav-icon">👤</span> Owners
            </div>
            <div class="nav-item" data-page="settings">
                <span class="nav-icon">⚙️</span> Settings
            </div>
        </nav>
        <div class="sidebar-footer">
            <span>Build a Higher Tomorrow</span>
        </div>
    </div>

    <!-- Main Content -->
    <div class="main-content">
        <!-- Top Bar -->
        <div class="top-bar">
            <h1>House List</h1>
            <div class="top-bar-actions">
                <div class="search-box">
                    <span class="search-icon">🔍</span>
                    <input type="text" id="searchInput" placeholder="Search houses by name or location..." value="${search}" />
                </div>
                <select class="filter-select" id="filterSelect">
                    <option value="all"${filter === "all" ? " selected" : ""}>All Locations</option>
                    ${locations.map(loc => `<option value="${loc}"${filter === loc ? " selected" : ""}>${loc}</option>`).join("")}
                </select>
                <button class="btn-primary" id="addHouseBtn">
                    <span>＋</span> Add House
                </button>
            </div>
        </div>

        <!-- Stats Row -->
        <div class="stats-row">
            <div class="stat-card gold">
                <div class="stat-label">Total Houses</div>
                <div class="stat-value">${stats.total}</div>
                <div class="stat-sub">Across ${locations.length} locations</div>
            </div>
            <div class="stat-card green">
                <div class="stat-label">Available</div>
                <div class="stat-value">${stats.available}</div>
                <div class="stat-sub">Ready to purchase</div>
            </div>
            <div class="stat-card red">
                <div class="stat-label">Owned</div>
                <div class="stat-value">${stats.owned}</div>
                <div class="stat-sub">Currently occupied</div>
            </div>
            <div class="stat-card blue">
                <div class="stat-label">Total Value</div>
                <div class="stat-value">${fmt(stats.totalValue)}</div>
                <div class="stat-sub">Combined market value</div>
            </div>
        </div>

        <!-- Table -->
        <div class="table-container">
            <table class="house-table">
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>House Name</th>
                        <th>Location</th>
                        <th>Price</th>
                        <th>Owner</th>
                        <th>Status</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    ${filtered.map((h, i) => `
                    <tr>
                        <td class="col-id">#${String(h.id).padStart(3, "0")}</td>
                        <td>
                            <div class="house-name-cell">
                                <div class="house-thumb">${HOUSE_ICONS[i % HOUSE_ICONS.length]}</div>
                                <span class="house-name-text">${h.name}</span>
                            </div>
                        </td>
                        <td>
                            <div class="col-location">
                                <span class="location-dot"></span>
                                ${h.location}
                            </div>
                        </td>
                        <td class="col-price">${fmt(h.price)}</td>
                        <td class="col-owner">${h.owner || "Unowned"}</td>
                        <td><span class="status-badge ${h.status}">${h.status.charAt(0).toUpperCase() + h.status.slice(1)}</span></td>
                        <td>
                            <div class="action-btns">
                                <button class="action-btn edit" title="Edit">✏️</button>
                                <button class="action-btn delete" title="Delete">🗑️</button>
                            </div>
                        </td>
                    </tr>
                    `).join("")}
                </tbody>
            </table>
        </div>

        <!-- Footer -->
        <div class="table-footer">
            <span>Showing ${filtered.length} of ${houses.length} houses</span>
            <button class="close-btn" id="closeBtn">✕ Close</button>
        </div>
    </div>
    `;
}

// ===== State =====
let currentFilter = "all";
let currentSearch = "";

function renderDashboard() {
    const dashboard = document.getElementById("dashboard");
    dashboard.innerHTML = buildDashboard(DUMMY_HOUSES, currentFilter, currentSearch);
    attachEvents();
}

function attachEvents() {
    // Search
    const searchInput = document.getElementById("searchInput");
    if (searchInput) {
        searchInput.addEventListener("input", (e) => {
            currentSearch = e.target.value;
            renderDashboard();
            // Refocus and restore cursor
            const el = document.getElementById("searchInput");
            el.focus();
            el.setSelectionRange(el.value.length, el.value.length);
        });
    }

    // Filter
    const filterSelect = document.getElementById("filterSelect");
    if (filterSelect) {
        filterSelect.addEventListener("change", (e) => {
            currentFilter = e.target.value;
            renderDashboard();
        });
    }

    // Close
    const closeBtn = document.getElementById("closeBtn");
    if (closeBtn) {
        closeBtn.addEventListener("click", () => {
            closeDashboard();
        });
    }

    // Add House
    const addHouseBtn = document.getElementById("addHouseBtn");
    if (addHouseBtn) {
        addHouseBtn.addEventListener("click", () => {
            openAddHouseModal();
        });
    }

    // Nav items (visual only for now)
    document.querySelectorAll(".nav-item").forEach(item => {
        item.addEventListener("click", () => {
            document.querySelectorAll(".nav-item").forEach(n => n.classList.remove("active"));
            item.classList.add("active");
        });
    });
}

// ===== Add House Modal =====
function openAddHouseModal() {
    // Remove existing modal if any
    const existing = document.getElementById("doorScanModal");
    if (existing) existing.remove();

    // Create modal overlay
    const modal = document.createElement("div");
    modal.id = "doorScanModal";
    modal.className = "modal-overlay";
    modal.innerHTML = `
        <div class="modal-panel">
            <div class="modal-header">
                <h2>🚪 Add New House</h2>
                <button class="modal-close-btn" id="modalCloseBtn">✕</button>
            </div>
            <div class="modal-body" id="modalBody">
                <div class="scan-loading">
                    <div class="scan-spinner"></div>
                    <div class="scan-text">Scanning for nearest doors...</div>
                    <div class="scan-subtext">Checking nearby objects in a 10m radius</div>
                </div>
            </div>
        </div>
    `;

    document.body.appendChild(modal);

    // Animate in
    requestAnimationFrame(() => modal.classList.add("active"));

    // Close button
    document.getElementById("modalCloseBtn").addEventListener("click", () => closeModal());

    // Backdrop close
    modal.addEventListener("click", (e) => {
        if (e.target === modal) closeModal();
    });

    // Trigger the scan
    scanForDoors();
}

function closeModal() {
    const modal = document.getElementById("doorScanModal");
    if (!modal) return;
    modal.classList.add("closing");
    setTimeout(() => modal.remove(), 250);
}

async function scanForDoors() {
    const modalBody = document.getElementById("modalBody");
    if (!modalBody) return;

    try {
        const response = await fetch(`https://${GetParentResourceName()}/scanDoors`, {
            method: "POST",
            body: JSON.stringify({ radius: 10.0 })
        });
        const result = await response.json();

        // Small delay so the user sees the loading animation
        setTimeout(() => renderDoorResults(result), 800);
    } catch (e) {
        // Running outside NUI — show dummy data for testing
        setTimeout(() => {
            renderDoorResults({
                count: 3,
                doors: [
                    { doorHash: 1948573021, model: -1504838576, distance: "1.24", state: 1, x: "-245.120", y: "732.540", z: "117.230" },
                    { doorHash: 832641057, model: 1327939172, distance: "2.87", state: 0, x: "-243.800", y: "734.100", z: "117.230" },
                    { doorHash: -476209183, model: -876291034, distance: "4.55", state: 1, x: "-247.650", y: "730.200", z: "117.230" },
                ]
            });
        }, 1200);
    }
}

function getDoorStateLabel(state) {
    switch (state) {
        case 0: return { text: "Unlocked", cls: "val-yes" };
        case 1: return { text: "Locked", cls: "val-no" };
        default: return { text: `State ${state}`, cls: "" };
    }
}

function renderDoorResults(result) {
    const modalBody = document.getElementById("modalBody");
    if (!modalBody) return;

    if (!result || result.count === 0) {
        modalBody.innerHTML = `
            <div class="scan-empty">
                <div class="scan-empty-icon">🔍</div>
                <div class="scan-empty-title">No DoorSystem Doors Found</div>
                <div class="scan-empty-sub">No registered doors were detected within 10m of your position.</div>
            </div>
        `;
        return;
    }

    modalBody.innerHTML = `
        <div class="scan-results-header">
            <span class="scan-found-count">Found <strong>${result.count}</strong> door${result.count !== 1 ? "s" : ""}</span>
            <span class="scan-found-sub">Validated via DoorSystem</span>
        </div>
        <div class="scan-results-list">
            ${result.doors.map((d, i) => {
                const stateInfo = getDoorStateLabel(d.state);
                return `
                <div class="door-card" style="animation-delay: ${i * 0.06}s">
                    <div class="door-card-header">
                        <span class="door-card-icon">🚪</span>
                        <span class="door-card-entity">Door #${d.doorHash}</span>
                        <span class="door-card-dist">${d.distance}m</span>
                    </div>
                    <div class="door-card-details">
                        <div class="door-detail">
                            <span class="door-detail-label">Door Hash</span>
                            <span class="door-detail-value">${d.doorHash}</span>
                        </div>
                        <div class="door-detail">
                            <span class="door-detail-label">Model Hash</span>
                            <span class="door-detail-value">${d.model}</span>
                        </div>
                        <div class="door-detail">
                            <span class="door-detail-label">State</span>
                            <span class="door-detail-value ${stateInfo.cls}">${stateInfo.text}</span>
                        </div>
                        <div class="door-detail">
                            <span class="door-detail-label">Position</span>
                            <span class="door-detail-value door-coords">${d.x}, ${d.y}, ${d.z}</span>
                        </div>
                    </div>
                    <div class="door-card-actions">
                        <button class="door-select-btn">Select as Door</button>
                    </div>
                </div>
                `;
            }).join("")}
        </div>
    `;
}

function closeDashboard() {
    const dashboard = document.getElementById("dashboard");
    dashboard.classList.add("closing");
    setTimeout(() => {
        dashboard.classList.add("hidden");
        dashboard.classList.remove("closing");
        // NUI close callback
        try {
            fetch(`https://${GetParentResourceName()}/close`, { method: "POST" });
        } catch (e) {
            // Running outside NUI
        }
    }, 280);
}

// ESC to close
document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
        const dashboard = document.getElementById("dashboard");
        if (dashboard && !dashboard.classList.contains("hidden")) {
            closeDashboard();
        }
    }
});
