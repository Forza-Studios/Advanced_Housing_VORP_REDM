// ===== COI Housing Manager — Dashboard Script =====

// House data — populated from server
let houseData = [];

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
                <button class="btn-secondary" id="refreshBtn" title="Refresh houses from database">
                    <span>🔄</span> Refresh
                </button>
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
                    ${filtered.length === 0 ? `
                    <tr>
                        <td colspan="7" style="text-align: center; padding: 30px; color: var(--text-muted);">
                            No houses saved in database yet. Click <strong>＋ Add House</strong> to scan doors and add houses!
                        </td>
                    </tr>
                    ` : filtered.map((h, i) => `
                    <tr>
                        <td class="col-id">#${String(h.id).padStart(3, "0")}</td>
                        <td>
                            <div class="house-name-cell">
                                <div class="house-thumb">🏠</div>
                                <div>
                                    <span class="house-name-text">${h.name}</span>
                                    <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;">🚪 ${(h.doors || []).length || 1} door${((h.doors || []).length || 1) !== 1 ? 's' : ''} | 📦 Stash: ${h.stashX ? (h.stashLimit || 100) + 'kg' : 'Not Set'}</div>
                                </div>
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
                        <td><span class="status-badge ${h.status || 'owned'}">${(h.locked === 1 || h.locked === true || h.locked === undefined) ? '🔒 Locked' : '🔓 Unlocked'}</span></td>
                        <td>
                            <div class="action-btns">
                                <button class="action-btn doors" title="Manage Doors (${(h.doors || []).length || 1})" data-id="${h.id}">🚪</button>
                                <button class="action-btn stash" title="📍 Set Stash at My Position" data-id="${h.id}">📦</button>
                                <button class="action-btn edit" title="Edit" data-id="${h.id}">✏️</button>
                                <button class="action-btn delete" title="Delete" data-id="${h.id}">🗑️</button>
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
    dashboard.innerHTML = buildDashboard(houseData, currentFilter, currentSearch);
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

    // Refresh
    const refreshBtn = document.getElementById("refreshBtn");
    if (refreshBtn) {
        refreshBtn.addEventListener("click", () => {
            try {
                fetch(`https://${GetParentResourceName()}/getHouses`, { method: "POST" });
            } catch (e) {}
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

    // Edit House
    document.querySelectorAll(".action-btn.edit").forEach(btn => {
        btn.addEventListener("click", () => {
            const houseId = btn.getAttribute("data-id");
            if (houseId) {
                const targetHouse = houseData.find(h => String(h.id) === String(houseId));
                if (targetHouse) {
                    openEditHouseModal(targetHouse);
                }
            }
        });
    });

    // Manage Doors
    document.querySelectorAll(".action-btn.doors").forEach(btn => {
        btn.addEventListener("click", () => {
            const houseId = btn.getAttribute("data-id");
            if (houseId) {
                const targetHouse = houseData.find(h => String(h.id) === String(houseId));
                if (targetHouse) {
                    openManageDoorsModal(targetHouse);
                }
            }
        });
    });

    // Set Stash Position
    document.querySelectorAll(".action-btn.stash").forEach(btn => {
        btn.addEventListener("click", () => {
            const houseId = btn.getAttribute("data-id");
            if (houseId) {
                try {
                    fetch(`https://${GetParentResourceName()}/setStashAtCurrentPos`, {
                        method: "POST",
                        body: JSON.stringify({ houseId: houseId })
                    });
                } catch (e) {}
            }
        });
    });

    // Delete House
    document.querySelectorAll(".action-btn.delete").forEach(btn => {
        btn.addEventListener("click", () => {
            const houseId = btn.getAttribute("data-id");
            if (houseId) {
                try {
                    fetch(`https://${GetParentResourceName()}/deleteHouse`, {
                        method: "POST",
                        body: JSON.stringify({ id: houseId })
                    });
                } catch (e) {}
            }
        });
    });

    // Nav items
    document.querySelectorAll(".nav-item").forEach(item => {
        item.addEventListener("click", () => {
            document.querySelectorAll(".nav-item").forEach(n => n.classList.remove("active"));
            item.classList.add("active");
        });
    });
}

// ===== Manage House Doors Modal (Multi-Door CRUD) =====
function openManageDoorsModal(house) {
    const existing = document.getElementById("manageDoorsModal");
    if (existing) existing.remove();

    const doors = (house.doors && house.doors.length > 0) ? house.doors : [
        { doorHash: house.doorHash, modelName: house.modelName, model: house.modelHash, x: house.x, y: house.y, z: house.z }
    ];

    const modal = document.createElement("div");
    modal.id = "manageDoorsModal";
    modal.className = "modal-overlay";
    modal.innerHTML = `
        <div class="modal-panel" style="max-width: 550px;">
            <div class="modal-header">
                <h2>🚪 Manage Doors — House #${house.id}</h2>
                <button class="modal-close-btn" id="doorsModalCloseBtn">✕</button>
            </div>
            <div class="modal-body" style="padding: 20px;">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px;">
                    <div>
                        <strong style="color: var(--accent); font-size: 14px;">${escapeHtml(house.name)}</strong>
                        <div style="font-size: 11px; color: var(--text-muted);">${doors.length} door(s) attached to this house</div>
                    </div>
                    <button class="btn-primary" id="attachNewDoorBtn" style="font-size: 12px; padding: 6px 12px;">＋ Attach Nearby Door</button>
                </div>

                <div style="display: flex; flex-direction: column; gap: 8px; max-height: 320px; overflow-y: auto;">
                    ${doors.map((d, index) => `
                        <div style="background: rgba(0,0,0,0.3); border: 1px solid var(--border-subtle); border-radius: 8px; padding: 10px 14px; display: flex; justify-content: space-between; align-items: center;">
                            <div>
                                <div style="font-weight: 700; color: #fff; font-size: 12px;">Door #${index + 1}: ${escapeHtml(d.modelName || 'Door #' + d.doorHash)}</div>
                                <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;">
                                    <strong>Hash:</strong> ${d.doorHash} | <strong>Pos:</strong> ${d.x}, ${d.y}, ${d.z}
                                </div>
                            </div>
                            ${doors.length > 1 ? `
                                <button class="action-btn delete detach-door-btn" data-hash="${d.doorHash}" title="Detach Door">🗑️</button>
                            ` : `
                                <span style="font-size: 10px; color: var(--text-muted); font-style: italic;">Primary Door</span>
                            `}
                        </div>
                    `).join("")}
                </div>
            </div>
        </div>
    `;

    document.body.appendChild(modal);
    requestAnimationFrame(() => modal.classList.add("active"));

    const closeDoorsModal = () => {
        modal.classList.add("closing");
        setTimeout(() => modal.remove(), 250);
    };

    document.getElementById("doorsModalCloseBtn").addEventListener("click", closeDoorsModal);

    modal.querySelectorAll(".detach-door-btn").forEach(btn => {
        btn.addEventListener("click", () => {
            const doorHash = btn.getAttribute("data-hash");
            if (doorHash) {
                try {
                    fetch(`https://${GetParentResourceName()}/removeDoorFromHouse`, {
                        method: "POST",
                        body: JSON.stringify({ houseId: house.id, doorHash: doorHash })
                    });
                } catch(e) {}
                closeDoorsModal();
            }
        });
    });

    document.getElementById("attachNewDoorBtn").addEventListener("click", () => {
        closeDoorsModal();
        openAddHouseModalForAttach(house);
    });
}

function openAddHouseModalForAttach(targetHouse) {
    attachTargetHouse = targetHouse;
    openAddHouseModal();
}

let currentScanRadius = 10.0;
let currentScanFilter = "";
let lastScanResult = { count: 0, doors: [] };
let attachTargetHouse = null; // Set when attaching a door directly to an existing house

// ===== Add House Modal =====
function openAddHouseModal() {
    // Remove existing modal if any
    const existing = document.getElementById("doorScanModal");
    if (existing) existing.remove();

    const titleText = attachTargetHouse 
        ? `🚪 Attach Door to House #${attachTargetHouse.id} (${escapeHtml(attachTargetHouse.name)})`
        : `🚪 Add New House / Scan Doors`;

    // Create modal overlay
    const modal = document.createElement("div");
    modal.id = "doorScanModal";
    modal.className = "modal-overlay";
    modal.innerHTML = `
        <div class="modal-panel">
            <div class="modal-header">
                <h2>${titleText}</h2>
                <button class="modal-close-btn" id="modalCloseBtn">✕</button>
            </div>
            <div class="modal-body" id="modalBody">
                <div class="scan-loading">
                    <div class="scan-spinner"></div>
                    <div class="scan-text">Scanning for nearest doors...</div>
                    <div class="scan-subtext">Searching map database & world objects in a 10m radius</div>
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

    // Trigger initial scan
    scanForDoors(10.0);
}

function closeModal() {
    attachTargetHouse = null;
    const modal = document.getElementById("doorScanModal");
    if (!modal) return;
    modal.classList.add("closing");
    setTimeout(() => modal.remove(), 250);
}

async function scanForDoors(radius = currentScanRadius) {
    currentScanRadius = parseFloat(radius) || 10.0;
    const modalBody = document.getElementById("modalBody");
    if (!modalBody) return;

    try {
        const response = await fetch(`https://${GetParentResourceName()}/scanDoors`, {
            method: "POST",
            body: JSON.stringify({ radius: currentScanRadius })
        });
        const result = await response.json();
        lastScanResult = result || { count: 0, doors: [] };
        renderDoorResults(lastScanResult);
    } catch (e) {
        // NUI fetch failed or running in browser test
        renderDoorResults(lastScanResult || { count: 0, doors: [] });
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

    let doors = (result && result.doors) ? result.doors : [];
    
    if (currentScanFilter.trim()) {
        const q = currentScanFilter.toLowerCase();
        doors = doors.filter(d =>
            String(d.doorHash).includes(q) ||
            String(d.model).includes(q) ||
            (d.modelName && d.modelName.toLowerCase().includes(q))
        );
    }

    modalBody.innerHTML = `
        <div class="scan-filter-bar">
            <input type="text" class="scan-filter-input" id="scanFilterInput" placeholder="Filter by door hash or model name..." value="${currentScanFilter}" />
            <div class="scan-radius-group">
                <label for="scanRadiusSelect">Radius:</label>
                <select class="scan-radius-select" id="scanRadiusSelect">
                    <option value="5"${currentScanRadius === 5 ? " selected" : ""}>5m</option>
                    <option value="10"${currentScanRadius === 10 ? " selected" : ""}>10m</option>
                    <option value="20"${currentScanRadius === 20 ? " selected" : ""}>20m</option>
                    <option value="50"${currentScanRadius === 50 ? " selected" : ""}>50m</option>
                </select>
            </div>
        </div>
        <div class="scan-results-header">
            <span class="scan-found-count">Found <strong>${doors.length}</strong> of <strong>${(result && result.count) || 0}</strong> door${(result && result.count) !== 1 ? "s" : ""}</span>
            <span class="scan-found-sub">Map Database & DoorSystem</span>
        </div>
        ${doors.length === 0 ? `
            <div class="scan-empty">
                <div class="scan-empty-icon">🔍</div>
                <div class="scan-empty-title">No Doors Found</div>
                <div class="scan-empty-sub">No doors detected within ${currentScanRadius}m radius matching criteria.</div>
            </div>
        ` : `
            <div class="scan-results-list">
                ${doors.map((d, i) => {
                    const stateInfo = getDoorStateLabel(d.state);
                    return `
                    <div class="door-card" style="animation-delay: ${i * 0.04}s">
                        <div class="door-card-header">
                            <span class="door-card-icon">🚪</span>
                            <span class="door-card-entity">${d.modelName || 'Door #' + d.doorHash}</span>
                            <span class="door-card-dist">${d.distance}m</span>
                        </div>
                        <div class="door-card-details">
                            <div class="door-detail">
                                <span class="door-detail-label">Door Hash</span>
                                <span class="door-detail-value">${d.doorHash}</span>
                            </div>
                            <div class="door-detail">
                                <span class="door-detail-label">Model Name</span>
                                <span class="door-detail-value">${d.modelName || 'Unknown'}</span>
                            </div>
                            <div class="door-detail">
                                <span class="door-detail-label">Model Hash</span>
                                <span class="door-detail-value">${d.model}</span>
                            </div>
                            <div class="door-detail">
                                <span class="door-detail-label">State</span>
                                <span class="door-detail-value ${stateInfo.cls}">${stateInfo.text}</span>
                            </div>
                            <div class="door-detail" style="grid-column: span 2;">
                                <span class="door-detail-label">Position (X, Y, Z)</span>
                                <span class="door-detail-value door-coords">${d.x}, ${d.y}, ${d.z}</span>
                            </div>
                        </div>
                        <div class="door-card-actions">
                            <button class="door-select-btn" data-hash="${d.doorHash}">Select as House Door</button>
                        </div>
                    </div>
                    `;
                }).join("")}
            </div>
        `}
    `;

    // Attach radius listener
    const radiusSelect = document.getElementById("scanRadiusSelect");
    if (radiusSelect) {
        radiusSelect.addEventListener("change", (e) => {
            const val = parseFloat(e.target.value);
            scanForDoors(val);
        });
    }

    // Attach filter input listener
    const filterInput = document.getElementById("scanFilterInput");
    if (filterInput) {
        filterInput.addEventListener("input", (e) => {
            currentScanFilter = e.target.value;
            renderDoorResults(lastScanResult);
            const el = document.getElementById("scanFilterInput");
            if (el) {
                el.focus();
                el.setSelectionRange(el.value.length, el.value.length);
            }
        });
    }

    // Attach select door buttons -> Attach to existing house or open Save House Modal
    document.querySelectorAll(".door-select-btn").forEach(btn => {
        if (attachTargetHouse) {
            btn.textContent = `➕ Attach to House #${attachTargetHouse.id}`;
            btn.style.background = "var(--accent)";
        }
        btn.addEventListener("click", () => {
            const doorHash = btn.getAttribute("data-hash");
            const selectedDoor = (lastScanResult.doors || []).find(d => String(d.doorHash) === String(doorHash));
            if (selectedDoor) {
                if (attachTargetHouse) {
                    try {
                        fetch(`https://${GetParentResourceName()}/addDoorToHouse`, {
                            method: "POST",
                            body: JSON.stringify({ houseId: attachTargetHouse.id, door: selectedDoor })
                        });
                    } catch(e) {}
                    closeModal();
                } else {
                    openSaveHouseModal(selectedDoor);
                }
            }
        });
    });
}

// ===== Save House Modal Form =====
function openSaveHouseModal(door) {
    closeModal(); // close door scan modal

    const existing = document.getElementById("saveHouseModal");
    if (existing) existing.remove();

    const modal = document.createElement("div");
    modal.id = "saveHouseModal";
    modal.className = "modal-overlay";
    modal.innerHTML = `
        <div class="modal-panel" style="max-width: 500px;">
            <div class="modal-header">
                <h2>🏠 Save House to Database</h2>
                <button class="modal-close-btn" id="saveModalCloseBtn">✕</button>
            </div>
            <div class="modal-body" style="padding: 20px;">
                <div style="display: flex; flex-direction: column; gap: 14px;">
                    <div>
                        <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-muted); display: block; margin-bottom: 4px;">House Name</label>
                        <input type="text" id="saveHouseName" class="scan-filter-input" style="width: 100%; font-size: 13px;" value="${door.modelName || ('House #' + door.doorHash)}" />
                    </div>
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
                        <div>
                            <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-muted); display: block; margin-bottom: 4px;">Location</label>
                            <select id="saveHouseLocation" class="scan-radius-select" style="width: 100%; font-size: 13px;">
                                <option value="Valentine">Valentine</option>
                                <option value="Saint Denis">Saint Denis</option>
                                <option value="Blackwater">Blackwater</option>
                                <option value="Rhodes">Rhodes</option>
                                <option value="Strawberry">Strawberry</option>
                                <option value="Armadillo">Armadillo</option>
                                <option value="Tumbleweed">Tumbleweed</option>
                                <option value="Annesburg">Annesburg</option>
                            </select>
                        </div>
                        <div>
                            <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-muted); display: block; margin-bottom: 4px;">Price ($)</label>
                            <input type="number" id="saveHousePrice" class="scan-filter-input" style="width: 100%; font-size: 13px;" value="500" min="1" step="10" />
                        </div>
                    </div>
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
                        <div>
                            <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-muted); display: block; margin-bottom: 4px;">Initial Owner / Status</label>
                            <select id="saveHouseOwnerMode" class="scan-radius-select" style="width: 100%; font-size: 13px;">
                                <option value="forsale">🏷️ For Sale (Public Purchase Prompt)</option>
                                <option value="creator">👤 You (Creator / Character Owner)</option>
                            </select>
                        </div>
                        <div>
                            <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-muted); display: block; margin-bottom: 4px;">Stash Capacity (kg)</label>
                            <input type="number" id="saveHouseStashLimit" class="scan-filter-input" style="width: 100%; font-size: 13px;" value="100" min="1" step="10" />
                        </div>
                    </div>
                    <div style="background: rgba(0,0,0,0.25); border: 1px solid var(--border-subtle); border-radius: 8px; padding: 12px; font-size: 12px; display: flex; flex-direction: column; gap: 6px;">
                        <div style="color: var(--accent); font-weight: 700;">Selected Door Settings</div>
                        <div><strong>Door Hash:</strong> ${door.doorHash}</div>
                        <div><strong>Model Name:</strong> ${door.modelName || 'Unknown'}</div>
                        <div><strong>Model Hash:</strong> ${door.model}</div>
                        <div><strong>Position:</strong> ${door.x}, ${door.y}, ${door.z}</div>
                        <div style="margin-top: 4px; padding-top: 6px; border-top: 1px dashed var(--border-subtle); display: flex; flex-direction: column; gap: 4px;">
                            <div style="display: flex; justify-content: space-between; align-items: center;">
                                <span><strong>Initial Lock State:</strong> <span style="color: #c07070;">🔒 Locked (True)</span></span>
                                <span><strong>Default Blip Sprite:</strong> <span style="color: var(--accent);">1586273744</span></span>
                            </div>
                        </div>
                    </div>
                    <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 10px;">
                        <button class="btn-secondary" id="saveModalCancelBtn">Cancel</button>
                        <button class="btn-primary" id="confirmSaveHouseBtn">💾 Save House</button>
                    </div>
                </div>
            </div>
        </div>
    `;

    document.body.appendChild(modal);
    requestAnimationFrame(() => modal.classList.add("active"));

    const closeSaveModal = () => {
        modal.classList.add("closing");
        setTimeout(() => modal.remove(), 250);
    };

    document.getElementById("saveModalCloseBtn").addEventListener("click", closeSaveModal);
    document.getElementById("saveModalCancelBtn").addEventListener("click", closeSaveModal);
    document.getElementById("confirmSaveHouseBtn").addEventListener("click", () => {
        const houseName = document.getElementById("saveHouseName").value.trim() || ("House #" + door.doorHash);
        const location = document.getElementById("saveHouseLocation").value;
        const price = parseFloat(document.getElementById("saveHousePrice").value) || 500;
        const ownerMode = document.getElementById("saveHouseOwnerMode").value;
        const ownerVal = (ownerMode === "forsale") ? "For Sale" : null;

        const payload = {
            name: houseName,
            location: location,
            price: price,
            owner: ownerVal,
            status: (ownerMode === "forsale") ? "available" : "owned",
            locked: 1, // Default locked = true (1)
            stashLimit: parseFloat(document.getElementById("saveHouseStashLimit").value) || 100,
            doorHash: door.doorHash,
            modelHash: door.model,
            modelName: door.modelName,
            x: door.x,
            y: door.y,
            z: door.z,
            heading: door.heading || 0.0,
            blipSprite: 1586273744,
            blipLabel: (ownerMode === "forsale") ? (`House For Sale ($${price})`) : ""
        };

        try {
            fetch(`https://${GetParentResourceName()}/createHouse`, {
                method: "POST",
                body: JSON.stringify(payload)
            });
        } catch(e) {}

        closeSaveModal();
    });
}

function escapeHtml(str) {
    if (!str) return "";
    return String(str)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

// ===== Edit House Modal Form =====
function openEditHouseModal(house) {
    const existing = document.getElementById("editHouseModal");
    if (existing) existing.remove();

    const isForSale = (house.owner === "For Sale" || house.status === "available");
    const defaultBlipLabel = house.blipLabel || (isForSale ? `House For Sale ($${house.price || 500})` : (house.owner ? (house.owner + "'s House") : "House"));

    const modal = document.createElement("div");
    modal.id = "editHouseModal";
    modal.className = "modal-overlay";
    modal.innerHTML = `
        <div class="modal-panel" style="max-width: 500px;">
            <div class="modal-header">
                <h2>✏️ Edit House #${house.id}</h2>
                <button class="modal-close-btn" id="editModalCloseBtn">✕</button>
            </div>
            <div class="modal-body" style="padding: 20px;">
                <div style="display: flex; flex-direction: column; gap: 14px;">
                    <div>
                        <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-muted); display: block; margin-bottom: 4px;">House Name</label>
                        <input type="text" id="editHouseName" class="scan-filter-input" style="width: 100%; font-size: 13px;" value="${escapeHtml(house.name || '')}" />
                    </div>
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
                        <div>
                            <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-muted); display: block; margin-bottom: 4px;">Location</label>
                            <select id="editHouseLocation" class="scan-radius-select" style="width: 100%; font-size: 13px;">
                                ${["Valentine", "Saint Denis", "Blackwater", "Rhodes", "Strawberry", "Armadillo", "Tumbleweed", "Annesburg"].map(loc => `<option value="${loc}"${house.location === loc ? " selected" : ""}>${loc}</option>`).join("")}
                            </select>
                        </div>
                        <div>
                            <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-muted); display: block; margin-bottom: 4px;">Price ($)</label>
                            <input type="number" id="editHousePrice" class="scan-filter-input" style="width: 100%; font-size: 13px;" value="${house.price || 500}" min="1" step="10" />
                        </div>
                    </div>
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
                        <div>
                            <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-muted); display: block; margin-bottom: 4px;">Owner</label>
                            <div style="display: flex; gap: 6px;">
                                <input type="text" id="editHouseOwner" class="scan-filter-input" style="flex: 1; font-size: 13px;" value="${escapeHtml(house.owner || 'For Sale')}" />
                                <button type="button" class="btn-secondary" id="setForSaleBtn" title="Set status to For Sale" style="padding: 0 10px; font-size: 11px; white-space: nowrap;">🏷️ Sale</button>
                            </div>
                        </div>
                        <div>
                            <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-muted); display: block; margin-bottom: 4px;">Lock State</label>
                            <select id="editHouseLocked" class="scan-radius-select" style="width: 100%; font-size: 13px;">
                                <option value="1"${(house.locked == 1 || house.locked == true || house.locked == "1" || house.locked == undefined) ? " selected" : ""}>🔒 Locked (True)</option>
                                <option value="0"${(house.locked == 0 || house.locked == false || house.locked == "0") ? " selected" : ""}>🔓 Unlocked (False)</option>
                            </select>
                        </div>
                    </div>
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
                        <div>
                            <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-muted); display: block; margin-bottom: 4px;">Blip Sprite</label>
                            <input type="number" id="editHouseBlipSprite" class="scan-filter-input" style="width: 100%; font-size: 13px;" value="${house.blipSprite || 1586273744}" />
                        </div>
                        <div>
                            <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-muted); display: block; margin-bottom: 4px;">Blip Label</label>
                            <input type="text" id="editHouseBlipLabel" class="scan-filter-input" style="width: 100%; font-size: 13px;" value="${escapeHtml(defaultBlipLabel)}" />
                        </div>
                    </div>
                    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
                        <div>
                            <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-muted); display: block; margin-bottom: 4px;">Stash Capacity (kg)</label>
                            <input type="number" id="editHouseStashLimit" class="scan-filter-input" style="width: 100%; font-size: 13px;" value="${house.stashLimit || 100}" min="1" step="10" />
                        </div>
                        <div>
                            <label style="font-size: 11px; font-weight: 600; text-transform: uppercase; color: var(--text-muted); display: block; margin-bottom: 4px;">Stash Location</label>
                            <button type="button" class="btn-secondary" id="setStashPosBtn" style="width: 100%; font-size: 11px; padding: 7px 8px; justify-content: center;" title="Set Stash at My Position">📍 Set Stash at My Position</button>
                        </div>
                    </div>
                    <div style="background: rgba(0,0,0,0.25); border: 1px solid var(--border-subtle); border-radius: 8px; padding: 12px; font-size: 12px; display: flex; flex-direction: column; gap: 4px;">
                        <div style="color: var(--accent); font-weight: 700;">Door & Stash Properties</div>
                        <div><strong>Door Hash:</strong> ${house.doorHash || 'N/A'}</div>
                        <div><strong>Model Name:</strong> ${house.modelName || 'Unknown'}</div>
                        <div><strong>Position:</strong> ${house.x}, ${house.y}, ${house.z}</div>
                        <div style="margin-top: 4px; padding-top: 6px; border-top: 1px dashed var(--border-subtle); color: var(--text-muted);">
                            <strong>Stash Location:</strong> ${house.stashX ? `(${Number(house.stashX).toFixed(2)}, ${Number(house.stashY).toFixed(2)}, ${Number(house.stashZ).toFixed(2)})` : 'Not Set (Stand in house & click button above)'}
                        </div>
                    </div>
                    <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 10px;">
                        <button class="btn-secondary" id="editModalCancelBtn">Cancel</button>
                        <button class="btn-primary" id="confirmEditHouseBtn">💾 Update House</button>
                    </div>
                </div>
            </div>
        </div>
    `;

    document.body.appendChild(modal);
    requestAnimationFrame(() => modal.classList.add("active"));

    const closeEditModal = () => {
        modal.classList.add("closing");
        setTimeout(() => modal.remove(), 250);
    };

    document.getElementById("editModalCloseBtn").addEventListener("click", closeEditModal);
    document.getElementById("editModalCancelBtn").addEventListener("click", closeEditModal);
    const setForSaleBtn = document.getElementById("setForSaleBtn");
    if (setForSaleBtn) {
        setForSaleBtn.addEventListener("click", () => {
            document.getElementById("editHouseOwner").value = "For Sale";
            const price = parseFloat(document.getElementById("editHousePrice").value) || 500;
            document.getElementById("editHouseBlipLabel").value = `House For Sale ($${price})`;
        });
    }
    const setStashPosBtn = document.getElementById("setStashPosBtn");
    if (setStashPosBtn) {
        setStashPosBtn.addEventListener("click", () => {
            try {
                fetch(`https://${GetParentResourceName()}/setStashAtCurrentPos`, {
                    method: "POST",
                    body: JSON.stringify({ houseId: house.id })
                });
            } catch (e) {}
        });
    }
    document.getElementById("confirmEditHouseBtn").addEventListener("click", () => {
        const name = document.getElementById("editHouseName").value.trim();
        const location = document.getElementById("editHouseLocation").value;
        const price = parseFloat(document.getElementById("editHousePrice").value) || 500;
        const owner = document.getElementById("editHouseOwner").value.trim();
        const locked = parseInt(document.getElementById("editHouseLocked").value);
        const blipSprite = parseInt(document.getElementById("editHouseBlipSprite").value) || 1586273744;
        const blipLabel = document.getElementById("editHouseBlipLabel").value.trim();
        const stashLimit = parseFloat(document.getElementById("editHouseStashLimit").value) || 100;

        const payload = {
            id: house.id,
            name: name,
            location: location,
            price: price,
            owner: owner,
            locked: locked,
            blipSprite: blipSprite,
            blipLabel: blipLabel,
            stashLimit: stashLimit
        };

        try {
            fetch(`https://${GetParentResourceName()}/updateHouse`, {
                method: "POST",
                body: JSON.stringify(payload)
            });
        } catch(e) {}

        closeEditModal();
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
