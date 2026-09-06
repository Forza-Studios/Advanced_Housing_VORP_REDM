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

    // Nav items (visual only for now)
    document.querySelectorAll(".nav-item").forEach(item => {
        item.addEventListener("click", () => {
            document.querySelectorAll(".nav-item").forEach(n => n.classList.remove("active"));
            item.classList.add("active");
        });
    });
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
