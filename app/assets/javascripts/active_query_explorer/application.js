var state = { data: [], activeClass: null };
var filters = { search: "", namespace: "", params: "" };
var executeUrl = document.body.getAttribute("data-execute-url");
var queriesUrl = document.body.getAttribute("data-queries-url");

// -- Data fetching --

function fetchQueries() {
  var main = document.getElementById("main");
  main.innerHTML = '<div class="loading">Loading queries...</div>';

  fetch(queriesUrl)
    .then(function(r) { return r.json(); })
    .then(function(data) {
      state.data = data;
      populateNamespaceFilter();
      document.getElementById("toolbar").style.display = "flex";
      applyFilters();
    })
    .catch(function(err) {
      main.innerHTML = '<div class="empty-state"><h2>Error loading queries</h2><p>' + escapeHtml(err.message) + '</p></div>';
    });
}

function refresh() {
  fetchQueries();
}

// -- Filtering --

function getFilteredData() {
  var search = filters.search.toLowerCase();
  var ns = filters.namespace;
  var paramFilter = filters.params;

  var result = [];
  state.data.forEach(function(group) {
    if (ns && group.namespace !== ns) return;

    var filteredObjects = [];
    group.query_objects.forEach(function(qo) {
      var filteredQueries = qo.queries.filter(function(q) {
        // Param filter
        var paramCount = q.params ? q.params.length : 0;
        if (paramFilter === "with" && paramCount === 0) return false;
        if (paramFilter === "without" && paramCount > 0) return false;

        // Text search
        if (search) {
          var haystack = [
            qo.class_name,
            q.name,
            q.description || "",
            (q.params || []).map(function(p) { return p.name; }).join(" ")
          ].join(" ").toLowerCase();
          return haystack.indexOf(search) >= 0;
        }
        return true;
      });

      if (filteredQueries.length > 0) {
        filteredObjects.push({
          class_name: qo.class_name,
          source_location: qo.source_location,
          queries: filteredQueries
        });
      }
    });

    if (filteredObjects.length > 0) {
      result.push({ namespace: group.namespace, query_objects: filteredObjects });
    }
  });
  return result;
}

function applyFilters() {
  filters.search = document.getElementById("search-input").value;
  filters.namespace = document.getElementById("namespace-filter").value;

  var filtered = getFilteredData();
  renderSidebar(filtered);
  renderMain(filtered);
  renderFilterSummary(filtered);
}

function setParamFilter(btn) {
  var group = btn.parentElement;
  group.querySelectorAll(".toggle-btn").forEach(function(b) { b.classList.remove("active"); });
  btn.classList.add("active");
  filters.params = btn.getAttribute("data-value");
  applyFilters();
}

function clearFilters() {
  document.getElementById("search-input").value = "";
  document.getElementById("namespace-filter").value = "";
  filters = { search: "", namespace: "", params: "" };
  var toggleBtns = document.querySelectorAll(".toggle-group .toggle-btn");
  toggleBtns.forEach(function(b) { b.classList.remove("active"); });
  toggleBtns[0].classList.add("active");
  applyFilters();
}

function populateNamespaceFilter() {
  var select = document.getElementById("namespace-filter");
  select.innerHTML = '<option value="">All namespaces</option>';
  state.data.forEach(function(group) {
    var ns = group.namespace || "(root)";
    var opt = document.createElement("option");
    opt.value = group.namespace;
    opt.textContent = ns;
    select.appendChild(opt);
  });
}

function renderFilterSummary(filtered) {
  var summary = document.getElementById("filter-summary");
  var isFiltered = filters.search || filters.namespace || filters.params;

  if (!isFiltered) {
    summary.style.display = "none";
    return;
  }

  var totalQueries = 0;
  var totalObjects = 0;
  filtered.forEach(function(g) {
    g.query_objects.forEach(function(qo) {
      totalObjects++;
      totalQueries += qo.queries.length;
    });
  });

  var parts = [];
  if (filters.search) parts.push('matching "' + escapeHtml(filters.search) + '"');
  if (filters.namespace) parts.push("in " + escapeHtml(filters.namespace));
  if (filters.params === "with") parts.push("with parameters");
  if (filters.params === "without") parts.push("without parameters");

  summary.style.display = "block";
  summary.innerHTML = "Showing " + totalQueries + " queries across " + totalObjects + " objects " + parts.join(", ") +
    '<a class="clear-link" onclick="clearFilters()">Clear filters</a>';
}

// -- Rendering --

function renderSidebar(data) {
  var nav = document.getElementById("sidebar-nav");
  if (data.length === 0) {
    nav.innerHTML = '<div style="padding:16px;color:var(--text-muted);font-size:13px;">No matches</div>';
    return;
  }

  var html = "";
  data.forEach(function(group) {
    var ns = group.namespace || "(root)";
    html += '<div class="namespace-group">';
    html += '<button class="namespace-toggle open" onclick="toggleNamespace(this)">';
    html += '<span class="arrow">&#9654;</span> ' + highlightText(ns);
    html += '</button>';
    html += '<div class="namespace-children open">';
    group.query_objects.forEach(function(qo) {
      var shortName = qo.class_name.split("::").pop();
      html += '<a class="query-class-link" data-class="' + escapeAttr(qo.class_name) + '" onclick="scrollToClass(\'' + escapeAttr(qo.class_name) + '\')">';
      html += highlightText(shortName);
      html += '</a>';
    });
    html += '</div></div>';
  });
  nav.innerHTML = html;
}

function renderMain(data) {
  var main = document.getElementById("main");

  if (state.data.length === 0) {
    main.innerHTML = '<div class="empty-state"><h2>No queries registered</h2><p>Define query objects that include ActiveQuery::Base to see them here.</p></div>';
    return;
  }

  if (data.length === 0) {
    main.innerHTML = '<div class="empty-state"><h2>No matching queries</h2><p>Try adjusting your search or filters.</p></div>';
    return;
  }

  var total = 0;
  var totalObjects = 0;
  data.forEach(function(g) {
    g.query_objects.forEach(function(qo) {
      totalObjects++;
      total += qo.queries.length;
    });
  });

  var html = '<div class="main-header"><h1>Query Explorer</h1>';
  html += '<p>' + total + ' queries across ' + totalObjects + ' objects</p></div>';

  data.forEach(function(group) {
    group.query_objects.forEach(function(qo) {
      html += renderQueryObject(qo);
    });
  });

  main.innerHTML = html;
}

function renderQueryObject(qo) {
  var id = qo.class_name.replace(/::/g, "-");
  var html = '<div class="query-object" id="qo-' + escapeAttr(id) + '">';

  html += '<div class="query-object-header">';
  html += '<h2>' + highlightText(qo.class_name) + '</h2>';
  if (qo.source_location) {
    var shortPath = shortenPath(qo.source_location.file);
    html += '<span class="source-location">' + escapeHtml(shortPath) + ':' + qo.source_location.line + '</span>';
  }
  html += '</div>';

  if (qo.queries.length === 0) {
    html += '<div style="padding:14px 18px;"><span class="no-params">No queries defined</span></div>';
  } else {
    qo.queries.forEach(function(q, i) {
      html += renderQueryCard(q, id + "-" + i, qo.class_name);
    });
  }

  html += '</div>';
  return html;
}

function renderQueryCard(q, cardId, className) {
  var paramCount = q.params ? q.params.length : 0;
  var html = '<div class="query-card">';

  html += '<div class="query-card-header" onclick="toggleCard(\'' + cardId + '\')">';
  html += '<span class="arrow" id="arrow-' + cardId + '">&#9654;</span>';
  html += '<span class="query-name">:' + highlightText(q.name) + '</span>';
  if (q.description) {
    html += '<span class="query-description">' + highlightText(q.description) + '</span>';
  }
  if (paramCount > 0) {
    html += '<span class="query-param-count">' + paramCount + ' param' + (paramCount > 1 ? 's' : '') + '</span>';
  }
  html += '</div>';

  html += '<div class="query-card-body" id="body-' + cardId + '">';
  if (paramCount > 0) {
    html += '<div class="params-section"><h4>Parameters</h4>';
    html += '<table class="params-table"><thead><tr>';
    html += '<th>Name</th><th>Type</th><th>Required</th><th>Default</th>';
    html += '</tr></thead><tbody>';
    q.params.forEach(function(p) {
      html += '<tr>';
      html += '<td class="param-name">' + highlightText(p.name) + '</td>';
      html += '<td><span class="type-tag">' + escapeHtml(p.type || "any") + '</span></td>';
      html += '<td>';
      if (p.optional) {
        html += '<span class="badge badge-optional">optional</span>';
      } else {
        html += '<span class="badge badge-required">required</span>';
      }
      html += '</td>';
      html += '<td>' + (p.default != null ? escapeHtml(String(p.default)) : '<span style="color:var(--text-muted)">—</span>') + '</td>';
      html += '</tr>';
    });
    html += '</tbody></table></div>';
  } else {
    html += '<span class="no-params">No parameters</span>';
  }

  // Execute form
  html += '<div class="execute-section">';
  html += '<div class="execute-form" id="form-' + cardId + '">';
  if (paramCount > 0) {
    q.params.forEach(function(p) {
      var placeholder = p.optional ? "optional" : "required";
      if (p.default != null) placeholder = "default: " + p.default;
      html += '<div class="form-field">';
      html += '<label>' + escapeHtml(p.name) + ' <span class="type-tag" style="font-size:10px;padding:0 4px;">' + escapeHtml(p.type || "any") + '</span></label>';
      html += '<input type="text" name="' + escapeAttr(p.name) + '" placeholder="' + escapeAttr(placeholder) + '"';
      if (!p.optional) html += ' required';
      html += '>';
      html += '</div>';
    });
  }
  html += '<button class="execute-btn" onclick="executeQuery(\'' + escapeAttr(className) + '\', \'' + escapeAttr(q.name) + '\', \'' + cardId + '\')">Execute</button>';
  html += '</div>';
  html += '<div class="result-section" id="result-' + cardId + '" style="display:none;">';
  html += '<h4>Result</h4>';
  html += '<div class="result-output" id="result-output-' + cardId + '"></div>';
  html += '<div class="result-meta" id="result-meta-' + cardId + '"></div>';
  html += '</div>';
  html += '</div>';

  html += '</div>';

  html += '</div>';
  return html;
}

// -- UI helpers --

function toggleCard(cardId) {
  var body = document.getElementById("body-" + cardId);
  var header = body.previousElementSibling;
  body.classList.toggle("open");
  header.classList.toggle("open");
}

function toggleNamespace(btn) {
  btn.classList.toggle("open");
  var children = btn.nextElementSibling;
  children.classList.toggle("open");
}

function scrollToClass(className) {
  var id = "qo-" + className.replace(/::/g, "-");
  var el = document.getElementById(id);
  if (el) {
    el.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  document.querySelectorAll(".query-class-link").forEach(function(link) {
    link.classList.toggle("active", link.getAttribute("data-class") === className);
  });
}

function shortenPath(path) {
  var idx = path.indexOf("/app/");
  return idx >= 0 ? path.substring(idx + 1) : path;
}

// -- Text utilities --

function escapeHtml(str) {
  var div = document.createElement("div");
  div.appendChild(document.createTextNode(String(str)));
  return div.innerHTML;
}

function escapeAttr(str) {
  return String(str).replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}

function highlightText(str) {
  var text = escapeHtml(str);
  if (!filters.search) return text;

  var search = escapeHtml(filters.search);
  var regex = new RegExp("(" + search.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + ")", "gi");
  return text.replace(regex, '<span class="highlight">$1</span>');
}

// -- Keyboard shortcut --

document.addEventListener("keydown", function(e) {
  if ((e.metaKey || e.ctrlKey) && e.key === "k") {
    e.preventDefault();
    var input = document.getElementById("search-input");
    if (input) input.focus();
  }
});

// -- Query execution --

function executeQuery(className, queryName, cardId) {
  var form = document.getElementById("form-" + cardId);
  var btn = form.querySelector(".execute-btn");
  var resultSection = document.getElementById("result-" + cardId);
  var resultOutput = document.getElementById("result-output-" + cardId);
  var resultMeta = document.getElementById("result-meta-" + cardId);

  var args = {};
  var inputs = form.querySelectorAll("input");
  inputs.forEach(function(input) {
    if (input.value !== "") {
      args[input.name] = input.value;
    }
  });

  btn.disabled = true;
  btn.textContent = "Running...";
  resultSection.style.display = "block";
  resultOutput.className = "result-output";
  resultOutput.textContent = "Executing...";
  resultMeta.textContent = "";

  var startTime = performance.now();

  var csrfToken = document.querySelector('meta[name="csrf-token"]');
  var headers = { "Content-Type": "application/json" };
  if (csrfToken) headers["X-CSRF-Token"] = csrfToken.getAttribute("content");

  fetch(executeUrl, {
    method: "POST",
    headers: headers,
    body: JSON.stringify({
      query_class: className,
      query_name: queryName,
      args: args
    })
  })
  .then(function(r) { return r.json().then(function(data) { return { ok: r.ok, data: data }; }); })
  .then(function(resp) {
    var elapsed = Math.round(performance.now() - startTime);

    if (resp.ok) {
      var result = resp.data.result;
      var text = typeof result === "string" ? result : JSON.stringify(result, null, 2);
      resultOutput.className = "result-output";
      resultOutput.textContent = text;

      var meta = elapsed + "ms";
      if (Array.isArray(result)) meta += " \u00b7 " + result.length + " row" + (result.length !== 1 ? "s" : "");
      resultMeta.textContent = meta;
    } else {
      resultOutput.className = "result-output result-error";
      resultOutput.textContent = resp.data.error || "Unknown error";
      resultMeta.textContent = elapsed + "ms";
    }
  })
  .catch(function(err) {
    resultOutput.className = "result-output result-error";
    resultOutput.textContent = "Network error: " + err.message;
  })
  .finally(function() {
    btn.disabled = false;
    btn.textContent = "Execute";
  });
}

fetchQueries();
