import os
from datetime import datetime

from flask import Flask, jsonify, request

app = Flask(__name__)

LOG_DIR = "/app/logs"
LOG_FILE = os.path.join(LOG_DIR, "app.log")
CONFIG_FILE = "/app/config/app.conf"

DEFAULT_GREETING = os.getenv("GREETING", "Welcome to the custom app")
DEFAULT_LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
DEFAULT_PORT = int(os.getenv("PORT", "5000"))


def ensure_log_dir():
    os.makedirs(LOG_DIR, exist_ok=True)


def load_config():
    config = {
        "greeting": DEFAULT_GREETING,
        "log_level": DEFAULT_LOG_LEVEL,
        "port": DEFAULT_PORT,
    }

    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "r", encoding="utf-8") as stream:
            for line in stream:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                if key == "GREETING":
                    config["greeting"] = value
                elif key == "LOG_LEVEL":
                    config["log_level"] = value
                elif key == "PORT":
                    try:
                        config["port"] = int(value)
                    except ValueError:
                        pass

    return config


def append_log(message: str):
    ensure_log_dir()
    timestamp = datetime.utcnow().isoformat(timespec="seconds") + "Z"
    record = f"{timestamp} {message}\n"
    with open(LOG_FILE, "a", encoding="utf-8") as log_file:
        log_file.write(record)
    app.logger.info(record.strip())


@app.route("/", methods=["GET"])
def root():
    config = load_config()
    return config["greeting"], 200


@app.route("/status", methods=["GET"])
def status():
    return jsonify({"status": "ok"})


@app.route("/log", methods=["POST"])
def log_endpoint():
    data = request.get_json(silent=True)
    if not data or "message" not in data:
        return jsonify({"error": "missing message"}), 400

    append_log(data["message"])
    return jsonify({"saved": data["message"]}), 201


@app.route("/logs", methods=["GET"])
def logs():
    ensure_log_dir()
    if not os.path.exists(LOG_FILE):
        return "", 200, {"Content-Type": "text/plain; charset=utf-8"}

    with open(LOG_FILE, "r", encoding="utf-8") as stream:
        return stream.read(), 200, {"Content-Type": "text/plain; charset=utf-8"}


if __name__ == "__main__":
    config = load_config()
    ensure_log_dir()
    app.logger.setLevel(config["log_level"])
    app.run(host="0.0.0.0", port=config["port"])
