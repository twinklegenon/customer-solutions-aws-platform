"""Ecommerce demo service: catalog, cart and orders in one Flask app.

PostgreSQL holds products and orders. Redis holds carts and a short-lived
copy of the catalog list. Settings come from environment variables.
"""
import json
import os
import time
import urllib.request
import uuid
from decimal import Decimal

import psycopg2
import psycopg2.extras
import redis
from flask import Flask, jsonify, make_response, render_template, request

app = Flask(__name__, static_folder="assets", static_url_path="/assets")

APP_ENV = os.environ.get("APP_ENV", "local")
DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
DB_NAME = os.environ.get("DB_NAME", "app")
DB_USER = os.environ.get("DB_USER", "app")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "app")
DB_SSLMODE = os.environ.get("DB_SSLMODE", "prefer")
REDIS_HOST = os.environ.get("REDIS_HOST", "localhost")
REDIS_PORT = int(os.environ.get("REDIS_PORT", "6379"))
REDIS_TLS = os.environ.get("REDIS_TLS", "false").lower() == "true"
COOKIE_SECURE = os.environ.get("COOKIE_SECURE", "false").lower() == "true"

CATALOG_KEY = "catalog:v1"
CATALOG_TTL = 60
CART_TTL = 3600

cache = redis.Redis(
    host=REDIS_HOST,
    port=REDIS_PORT,
    ssl=REDIS_TLS,
    decode_responses=True,
    socket_connect_timeout=3,
    socket_timeout=3,
)

SCHEMA = """
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0)
);
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    items JSONB NOT NULL,
    total NUMERIC(10, 2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'PAID',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
"""

SEED = [
    ("The Pragmatic Programmer", "29.99", 42),
    ("Atomic Habits", "18.50", 120),
    ("Dune", "24.00", 8),
    ("The Hobbit", "12.75", 65),
]

schema_ready = False


def connect():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        sslmode=DB_SSLMODE,
        connect_timeout=5,
    )


def ensure_schema():
    """Create the tables once. An advisory lock keeps two tasks from racing."""
    global schema_ready
    if schema_ready:
        return
    conn = connect()
    try:
        with conn, conn.cursor() as cur:
            cur.execute("SELECT pg_advisory_xact_lock(7001)")
            cur.execute(SCHEMA)
            cur.execute("SELECT count(*) FROM products")
            if cur.fetchone()[0] == 0:
                cur.executemany(
                    "INSERT INTO products (name, price, stock) VALUES (%s, %s, %s)", SEED
                )
        schema_ready = True
    finally:
        conn.close()


def task_info():
    """Availability zone and task id from the ECS metadata endpoint."""
    uri = os.environ.get("ECS_CONTAINER_METADATA_URI_V4")
    if not uri:
        return {"az": "local", "task": "local"}
    try:
        with urllib.request.urlopen(uri + "/task", timeout=2) as resp:
            data = json.load(resp)
        return {
            "az": data.get("AvailabilityZone", "unknown"),
            "task": data.get("TaskARN", "unknown").split("/")[-1][:8],
        }
    except Exception:
        return {"az": "unknown", "task": "unknown"}


TASK = task_info()


def jsonable(value):
    if isinstance(value, Decimal):
        return float(value)
    raise TypeError(str(type(value)))


def respond(payload, status=200, cache_state="none", started=None):
    """Attach where the request was served and how long it took."""
    payload["meta"] = {
        "az": TASK["az"],
        "task": TASK["task"],
        "cache": cache_state,
        "ms": round((time.time() - started) * 1000) if started else 0,
    }
    return app.response_class(
        json.dumps(payload, default=jsonable), status=status, mimetype="application/json"
    )


def session_id():
    return request.cookies.get("sid") or uuid.uuid4().hex


def with_cookie(resp, sid):
    resp.set_cookie("sid", sid, httponly=True, samesite="Lax", secure=COOKIE_SECURE, max_age=CART_TTL)
    return resp


def load_products():
    """Return (products, cache_state). The list is cached in Redis."""
    try:
        cached = cache.get(CATALOG_KEY)
        if cached:
            return json.loads(cached), "hit"
    except redis.RedisError:
        pass
    ensure_schema()
    conn = connect()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("SELECT id, name, price, stock FROM products ORDER BY id DESC")
            rows = [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()
    for r in rows:
        r["price"] = float(r["price"])
    try:
        cache.setex(CATALOG_KEY, CATALOG_TTL, json.dumps(rows))
    except redis.RedisError:
        pass
    return rows, "miss"


def clear_catalog_cache():
    try:
        cache.delete(CATALOG_KEY)
    except redis.RedisError:
        pass


@app.errorhandler(psycopg2.Error)
def db_error(err):
    return respond({"error": "The database is not available yet. Try again in a moment."}, 503)


@app.errorhandler(redis.RedisError)
def cache_error(err):
    return respond({"error": "The cache is not available yet. Try again in a moment."}, 503)


@app.get("/")
def index():
    return render_template("index.html", env=APP_ENV)


@app.get("/health")
def health():
    return "ok", 200


# ---- catalog -------------------------------------------------------------

@app.get("/api/catalog")
def catalog_list():
    started = time.time()
    products, state = load_products()
    return respond({"items": products}, cache_state=state, started=started)


@app.post("/api/catalog")
def catalog_add():
    started = time.time()
    body = request.get_json(silent=True) or {}
    name = str(body.get("name", "")).strip()
    try:
        price = Decimal(str(body.get("price")))
        stock = int(body.get("stock", 0))
    except Exception:
        return respond({"error": "Price and stock must be numbers."}, 400)
    if not name or price < 0 or stock < 0:
        return respond({"error": "Enter a name, a price of 0 or more, and a stock of 0 or more."}, 400)
    ensure_schema()
    conn = connect()
    try:
        with conn, conn.cursor() as cur:
            cur.execute(
                "INSERT INTO products (name, price, stock) VALUES (%s, %s, %s) RETURNING id",
                (name[:120], price, stock),
            )
            new_id = cur.fetchone()[0]
    finally:
        conn.close()
    clear_catalog_cache()
    return respond({"id": new_id}, 201, started=started)


@app.delete("/api/catalog/<int:product_id>")
def catalog_delete(product_id):
    started = time.time()
    ensure_schema()
    conn = connect()
    try:
        with conn, conn.cursor() as cur:
            cur.execute("DELETE FROM products WHERE id = %s", (product_id,))
    finally:
        conn.close()
    clear_catalog_cache()
    return respond({"deleted": product_id}, started=started)


# ---- cart (Redis only) -----------------------------------------------------

def cart_key(sid):
    return "cart:" + sid


def cart_view(sid):
    raw = cache.hgetall(cart_key(sid))
    products, state = load_products()
    by_id = {str(p["id"]): p for p in products}
    lines, total = [], 0.0
    for pid, qty in raw.items():
        product = by_id.get(pid)
        if not product:
            continue
        line = round(product["price"] * int(qty), 2)
        total += line
        lines.append({"id": product["id"], "name": product["name"], "price": product["price"], "qty": int(qty), "line": line})
    return {"lines": lines, "total": round(total, 2)}, state


@app.get("/api/cart")
def cart_get():
    started = time.time()
    sid = session_id()
    view, _ = cart_view(sid)
    return with_cookie(respond(view, cache_state="hit", started=started), sid)


@app.post("/api/cart/items")
def cart_add():
    started = time.time()
    sid = session_id()
    body = request.get_json(silent=True) or {}
    pid = str(body.get("product_id", ""))
    if not pid.isdigit():
        return respond({"error": "Choose a product."}, 400)
    cache.hincrby(cart_key(sid), pid, 1)
    cache.expire(cart_key(sid), CART_TTL)
    view, _ = cart_view(sid)
    return with_cookie(respond(view, cache_state="none", started=started), sid)


@app.put("/api/cart/items/<int:product_id>")
def cart_set(product_id):
    started = time.time()
    sid = session_id()
    body = request.get_json(silent=True) or {}
    try:
        qty = int(body.get("qty", 1))
    except Exception:
        return respond({"error": "Quantity must be a number."}, 400)
    if qty < 1:
        cache.hdel(cart_key(sid), str(product_id))
    else:
        cache.hset(cart_key(sid), str(product_id), qty)
        cache.expire(cart_key(sid), CART_TTL)
    view, _ = cart_view(sid)
    return with_cookie(respond(view, started=started), sid)


@app.delete("/api/cart/items/<int:product_id>")
def cart_remove(product_id):
    started = time.time()
    sid = session_id()
    cache.hdel(cart_key(sid), str(product_id))
    view, _ = cart_view(sid)
    return with_cookie(respond(view, started=started), sid)


# ---- checkout and orders ---------------------------------------------------

@app.post("/api/checkout")
def checkout():
    started = time.time()
    sid = session_id()
    view, _ = cart_view(sid)
    if not view["lines"]:
        return with_cookie(respond({"error": "Your cart is empty."}, 400), sid)
    ensure_schema()
    conn = connect()
    try:
        with conn, conn.cursor() as cur:
            for line in view["lines"]:
                cur.execute(
                    "UPDATE products SET stock = stock - %s WHERE id = %s AND stock >= %s",
                    (line["qty"], line["id"], line["qty"]),
                )
                if cur.rowcount != 1:
                    conn.rollback()
                    return with_cookie(
                        respond({"error": "Not enough stock for " + line["name"] + "."}, 409), sid
                    )
            items = ", ".join(str(l["qty"]) + " x " + l["name"] for l in view["lines"])
            cur.execute(
                "INSERT INTO orders (items, total) VALUES (%s, %s) RETURNING id",
                (json.dumps({"text": items}), view["total"]),
            )
            order_id = cur.fetchone()[0]
    finally:
        conn.close()
    cache.delete(cart_key(sid))
    clear_catalog_cache()
    return with_cookie(respond({"order_id": order_id}, 201, started=started), sid)


@app.get("/api/orders")
def orders_list():
    started = time.time()
    ensure_schema()
    conn = connect()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("SELECT id, items, total, status, created_at FROM orders ORDER BY id DESC LIMIT 50")
            rows = cur.fetchall()
    finally:
        conn.close()
    out = [
        {
            "id": r["id"],
            "items": r["items"].get("text", ""),
            "total": float(r["total"]),
            "status": r["status"],
            "created": r["created_at"].strftime("%Y-%m-%d %H:%M"),
        }
        for r in rows
    ]
    return respond({"items": out}, started=started)


@app.put("/api/orders/<int:order_id>")
def orders_status(order_id):
    started = time.time()
    body = request.get_json(silent=True) or {}
    status = str(body.get("status", ""))
    if status not in ("PAID", "SHIPPED", "CANCELLED"):
        return respond({"error": "Status must be PAID, SHIPPED or CANCELLED."}, 400)
    ensure_schema()
    conn = connect()
    try:
        with conn, conn.cursor() as cur:
            cur.execute("UPDATE orders SET status = %s WHERE id = %s", (status, order_id))
    finally:
        conn.close()
    return respond({"id": order_id, "status": status}, started=started)


@app.delete("/api/orders/<int:order_id>")
def orders_delete(order_id):
    started = time.time()
    ensure_schema()
    conn = connect()
    try:
        with conn, conn.cursor() as cur:
            cur.execute("DELETE FROM orders WHERE id = %s", (order_id,))
    finally:
        conn.close()
    return respond({"deleted": order_id}, started=started)


# ---- system ----------------------------------------------------------------

@app.get("/api/system")
def system():
    started = time.time()
    db_ok = redis_ok = False
    try:
        conn = connect()
        conn.close()
        db_ok = True
    except Exception:
        pass
    try:
        redis_ok = bool(cache.ping())
    except Exception:
        pass
    return respond(
        {"env": APP_ENV, "database": db_ok, "redis": redis_ok},
        started=started,
    )
