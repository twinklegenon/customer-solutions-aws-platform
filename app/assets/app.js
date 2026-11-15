(function () {
  "use strict";

  var state = { tab: "catalog", log: [], last: null, steps: [], cartCount: 0 };

  function $(id) { return document.getElementById(id); }

  function el(tag, props, children) {
    var node = document.createElement(tag);
    Object.keys(props || {}).forEach(function (k) {
      if (k === "class") { node.className = props[k]; }
      else if (k === "text") { node.textContent = props[k]; }
      else if (k.indexOf("on") === 0) { node.addEventListener(k.slice(2), props[k]); }
      else { node.setAttribute(k, props[k]); }
    });
    (children || []).forEach(function (c) { node.appendChild(c); });
    return node;
  }

  function money(n) { return "$" + Number(n).toFixed(2); }

  function showMessage(text, ok) {
    var m = $("message");
    if (!text) { m.hidden = true; return; }
    m.textContent = text;
    m.className = "message" + (ok ? " ok" : "");
    m.hidden = false;
  }

  // Which parts of the stack each kind of request touches.
  function pathFor(kind, cache) {
    var base = ["cf", "alb", "app"];
    if (kind === "catalog") { return base.concat(cache === "hit" ? ["redis"] : ["redis", "db"]); }
    if (kind === "catalog-write") { return base.concat(["db", "redis"]); }
    if (kind === "cart") { return base.concat(["redis"]); }
    if (kind === "checkout") { return base.concat(["redis", "db"]); }
    if (kind === "orders") { return base.concat(["db"]); }
    return base;
  }

  function call(method, path, body, kind) {
    var opts = { method: method, headers: {}, credentials: "same-origin" };
    if (body) { opts.headers["Content-Type"] = "application/json"; opts.body = JSON.stringify(body); }
    return fetch(path, opts).then(function (resp) {
      return resp.json().then(function (data) {
        var meta = data.meta || {};
        state.last = { method: method, path: path, status: resp.status, meta: meta };
        state.steps = pathFor(kind, meta.cache);
        state.log.unshift({ line: method + " " + path + (meta.cache && meta.cache !== "none" ? " (cache " + meta.cache + ")" : ""), status: resp.status, ms: meta.ms || 0 });
        state.log = state.log.slice(0, 6);
        renderMeta();
        if (!resp.ok) { showMessage(data.error || "Something went wrong.", false); }
        else { showMessage(""); }
        return { ok: resp.ok, data: data };
      });
    }).catch(function () {
      showMessage("Could not reach the service. Try again.", false);
      return { ok: false, data: {} };
    });
  }

  function renderMeta() {
    var meta = $("meta");
    meta.textContent = "";
    if (!state.last || state.tab === "system") { return; }
    var m = state.last.meta;
    var cache = m.cache || "none";
    var label = cache === "hit" ? "cache hit" : cache === "miss" ? "cache miss" : "no cache read";
    meta.appendChild(el("span", { class: "pill " + cache, text: label }));
    meta.appendChild(el("span", { text: state.last.method + " " + state.last.path }));
    meta.appendChild(el("span", { text: (m.ms || 0) + " ms" }));
    meta.appendChild(el("span", { text: "served from " + (m.az || "unknown") }));
  }

  // ---- catalog ----
  function loadCatalog() {
    return call("GET", "/api/catalog", null, "catalog").then(function (r) {
      var box = $("catalog-list");
      box.textContent = "";
      var items = (r.data && r.data.items) || [];
      if (!r.ok) { return; }
      if (!items.length) { box.appendChild(el("div", { class: "empty", text: "The catalog is empty. Add a product above." })); return; }
      items.forEach(function (p) {
        box.appendChild(el("div", { class: "item" }, [
          el("div", { class: "main" }, [
            el("div", { class: "name", text: p.name }),
            el("div", { class: "sub", text: "P-" + p.id + " · " + (p.stock > 0 ? p.stock + " in stock" : "out of stock") })
          ]),
          el("div", { class: "price", text: money(p.price) }),
          el("div", { class: "actions" }, [
            el("button", { type: "button", class: "primary", text: "Add to cart", onclick: function () { addToCart(p.id); } }),
            el("button", { type: "button", class: "danger", text: "Delete", onclick: function () { removeProduct(p.id); } })
          ])
        ]));
      });
    });
  }

  function addToCart(id) {
    call("POST", "/api/cart/items", { product_id: id }, "cart").then(function (r) {
      if (r.ok) { updateCartCount(r.data); showMessage("Added to your cart.", true); }
    });
  }

  function removeProduct(id) {
    call("DELETE", "/api/catalog/" + id, null, "catalog-write").then(function (r) { if (r.ok) { loadCatalog(); } });
  }

  $("product-form").addEventListener("submit", function (event) {
    event.preventDefault();
    var body = { name: $("p-name").value, price: $("p-price").value, stock: $("p-stock").value || 0 };
    call("POST", "/api/catalog", body, "catalog-write").then(function (r) {
      if (r.ok) { $("product-form").reset(); loadCatalog(); showMessage("Product added.", true); }
    });
  });

  // ---- cart ----
  function updateCartCount(view) {
    var n = 0;
    ((view && view.lines) || []).forEach(function (l) { n += l.qty; });
    state.cartCount = n;
    $("cart-count").textContent = n;
  }

  function loadCart() {
    return call("GET", "/api/cart", null, "cart").then(function (r) {
      if (!r.ok) { return; }
      updateCartCount(r.data);
      var box = $("cart-list");
      box.textContent = "";
      var lines = r.data.lines || [];
      $("cart-footer").hidden = !lines.length;
      if (!lines.length) { box.appendChild(el("div", { class: "empty", text: "Your cart is empty. Add something from the catalog." })); return; }
      $("cart-total").textContent = "Total " + money(r.data.total);
      lines.forEach(function (l) {
        box.appendChild(el("div", { class: "item" }, [
          el("div", { class: "main" }, [
            el("div", { class: "name", text: l.name }),
            el("div", { class: "sub", text: money(l.price) + " each" })
          ]),
          el("div", { class: "qty" }, [
            el("button", { type: "button", "aria-label": "One fewer", text: "-", onclick: function () { setQty(l.id, l.qty - 1); } }),
            el("span", { text: String(l.qty) }),
            el("button", { type: "button", "aria-label": "One more", text: "+", onclick: function () { setQty(l.id, l.qty + 1); } })
          ]),
          el("div", { class: "price", text: money(l.line) }),
          el("button", { type: "button", class: "danger", text: "Remove", onclick: function () { removeLine(l.id); } })
        ]));
      });
    });
  }

  function setQty(id, qty) {
    call("PUT", "/api/cart/items/" + id, { qty: qty }, "cart").then(function (r) { if (r.ok) { loadCart(); } });
  }
  function removeLine(id) {
    call("DELETE", "/api/cart/items/" + id, null, "cart").then(function (r) { if (r.ok) { loadCart(); } });
  }

  $("checkout").addEventListener("click", function () {
    call("POST", "/api/checkout", null, "checkout").then(function (r) {
      if (r.ok) { showMessage("Order " + r.data.order_id + " created.", true); updateCartCount({ lines: [] }); show("orders"); }
    });
  });

  // ---- orders ----
  function loadOrders() {
    return call("GET", "/api/orders", null, "orders").then(function (r) {
      if (!r.ok) { return; }
      var box = $("orders-list");
      box.textContent = "";
      var items = r.data.items || [];
      if (!items.length) { box.appendChild(el("div", { class: "empty", text: "No orders yet. Check out a cart to create one." })); return; }
      items.forEach(function (o) {
        var select = el("select", { "aria-label": "Order status", onchange: function (e) { setStatus(o.id, e.target.value); } });
        ["PAID", "SHIPPED", "CANCELLED"].forEach(function (s) {
          var opt = el("option", { value: s, text: s.charAt(0) + s.slice(1).toLowerCase() });
          if (s === o.status) { opt.selected = true; }
          select.appendChild(opt);
        });
        box.appendChild(el("div", { class: "item" }, [
          el("div", { class: "main" }, [
            el("div", { class: "sub", text: "ORD-" + o.id + " · " + o.created }),
            el("div", { class: "name", text: o.items })
          ]),
          el("div", { class: "price", text: money(o.total) }),
          el("div", { class: "actions" }, [
            select,
            el("button", { type: "button", class: "danger", text: "Delete", onclick: function () { removeOrder(o.id); } })
          ])
        ]));
      });
    });
  }
  function setStatus(id, status) { call("PUT", "/api/orders/" + id, { status: status }, "orders"); }
  function removeOrder(id) { call("DELETE", "/api/orders/" + id, null, "orders").then(function (r) { if (r.ok) { loadOrders(); } }); }

  // ---- system ----
  function loadSystem() {
    return call("GET", "/api/system", null, "system").then(function (r) {
      var m = state.last ? state.last.meta : {};
      var served = $("served");
      served.textContent = "";
      [["Availability zone", m.az || "unknown"], ["Task", m.task || "unknown"], ["Environment", r.data.env || ""]].forEach(function (row) {
        served.appendChild(el("dt", { text: row[0] }));
        served.appendChild(el("dd", { text: row[1] }));
      });

      var deps = $("deps");
      deps.textContent = "";
      [["PostgreSQL", r.data.database], ["Redis", r.data.redis]].forEach(function (d) {
        deps.appendChild(el("li", {}, [
          el("span", { text: d[0] }),
          el("span", { class: d[1] ? "ok" : "down", text: d[1] ? "connected" : "unreachable" })
        ]));
      });

      var labels = [["cf", "CloudFront and WAF", "TLS, filtered"], ["alb", "Load balancer", "HTTPS"], ["app", "Application task", m.az ? m.az.slice(-2) : ""], ["redis", "Redis", "cache and carts"], ["db", "PostgreSQL", "products, orders"]];
      var path = $("path");
      path.textContent = "";
      labels.forEach(function (l) {
        var on = state.steps.indexOf(l[0]) !== -1;
        path.appendChild(el("li", { class: on ? "on" : "" }, [
          el("span", { class: "dot" }), el("span", { text: l[1] }), el("span", { class: "tag", text: l[2] })
        ]));
      });

      var log = $("log");
      log.textContent = "";
      state.log.forEach(function (l) {
        log.appendChild(el("div", {}, [
          el("span", { text: l.line + " → " + l.status }),
          el("span", { class: "ms", text: l.ms + " ms" })
        ]));
      });
    });
  }

  $("ping").addEventListener("click", function () { loadSystem(); });

  // ---- tabs ----
  function show(tab) {
    state.tab = tab;
    ["catalog", "cart", "orders", "system"].forEach(function (t) { $("view-" + t).hidden = t !== tab; });
    document.querySelectorAll(".tab").forEach(function (b) {
      if (b.getAttribute("data-tab") === tab) { b.setAttribute("aria-current", "page"); } else { b.removeAttribute("aria-current"); }
    });
    showMessage("");
    if (tab === "catalog") { loadCatalog(); }
    if (tab === "cart") { loadCart(); }
    if (tab === "orders") { loadOrders(); }
    if (tab === "system") { loadSystem(); }
    renderMeta();
  }

  document.querySelectorAll(".tab").forEach(function (b) {
    b.addEventListener("click", function () { show(b.getAttribute("data-tab")); });
  });

  show("catalog");
})();
