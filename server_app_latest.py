from __future__ import annotations

import hashlib
import io
import mimetypes
import os
import secrets
import shutil
import sqlite3
import tempfile
from pathlib import Path

from PIL import Image, UnidentifiedImageError
from flask import Flask, jsonify, request, send_file

app = Flask(__name__)

# Directory setup
BASE_DIR = Path.home() / "music-library"
CURRENT_VERSION = "1.0.4"
RELEASES_DIR = BASE_DIR / "releases"
RELEASES_DIR.mkdir(parents=True, exist_ok=True)

INVITE_CODE = os.environ.get("SHOGUNIFY_INVITE_CODE", "changeme")
MUSIC_DIR = BASE_DIR / "songs"
ALBUM_ART_DIR = BASE_DIR / "album_art"
DB_PATH = BASE_DIR / "music.db"

MUSIC_DIR.mkdir(parents=True, exist_ok=True)
ALBUM_ART_DIR.mkdir(parents=True, exist_ok=True)
PREVIEW_DIR = BASE_DIR / "previews"
PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
PREVIEWS: dict[str, dict] = {}

# Keep uploads bounded. The audio limit is intentionally generous for MP3s.
app.config["MAX_CONTENT_LENGTH"] = 256 * 1024 * 1024
MAX_ALBUM_ART_BYTES = 10 * 1024 * 1024
ALLOWED_AUDIO_EXTENSIONS = {".mp3"}


def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def error_response(code: str, message: str, status: int):
    return jsonify({"error": {"code": code, "message": message}}), status


def song_query():
    return """
        SELECT songs.id, songs.title, songs.artist, songs.filename,
               songs.duration, songs.source_type, songs.source_video_id,
               songs.source_url, songs.added_date, songs.updated_at,
               album_art.filename AS album_art_filename
        FROM songs
        LEFT JOIN album_art ON songs.album_art_id = album_art.id
    """


def serialize_song(row: sqlite3.Row) -> dict:
    result = {
        "id": row["id"],
        "title": row["title"],
        "artist": row["artist"],
        "filename": row["filename"],
        "duration": row["duration"],
        "stream_url": f"/stream/{row['filename']}",
        "album_art_url": (
            f"/album_art/{row['album_art_filename']}"
            if row["album_art_filename"]
            else None
        ),
        "added_date": row["added_date"],
    }
    if row["source_type"] or row["source_video_id"] or row["source_url"]:
        result["source"] = {
            "type": row["source_type"],
            "video_id": row["source_video_id"],
            "url": row["source_url"],
        }
    return result


def process_album_art(file_storage):
    """Return (jpeg_bytes, sha256, filename), or a structured error tuple."""
    if file_storage is None or not file_storage.filename:
        return None
    raw = file_storage.read(MAX_ALBUM_ART_BYTES + 1)
    if len(raw) > MAX_ALBUM_ART_BYTES:
        raise ValueError("Album art is larger than 10 MB.")
    try:
        image = Image.open(io.BytesIO(raw))
        image.verify()
        image = Image.open(io.BytesIO(raw)).convert("RGB")
    except (UnidentifiedImageError, OSError) as exc:
        raise ValueError("Album art is not a valid image.") from exc

    output = io.BytesIO()
    image.save(output, format="JPEG", quality=85, optimize=True)
    jpeg_bytes = output.getvalue()
    file_hash = hashlib.sha256(jpeg_bytes).hexdigest()
    return jpeg_bytes, file_hash, f"{file_hash}.jpg"


def save_part(data: bytes, directory: Path, suffix: str) -> Path:
    fd, name = tempfile.mkstemp(prefix="upload_", suffix=suffix + ".part", dir=directory)
    path = Path(name)
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        return path
    except Exception:
        path.unlink(missing_ok=True)
        raise


@app.errorhandler(413)
def request_too_large(_error):
    return error_response("UPLOAD_TOO_LARGE", "The upload exceeds the 256 MB limit.", 413)


@app.route("/api/songs", methods=["GET"])
def list_songs():
    conn = get_db()
    try:
        rows = conn.execute(
            song_query() + " WHERE songs.is_deleted = 0 ORDER BY songs.id"
        ).fetchall()
        return jsonify([serialize_song(row) for row in rows])
    finally:
        conn.close()


@app.route('/api/version', methods=['GET'])
def check_version():
    return jsonify({
        'latest_version': CURRENT_VERSION,
        'download_url': 'https://music.wannuwatbot.com/download/apk'
    })

@app.route('/download/apk', methods=['GET'])
def download_apk():
    apk_path = RELEASES_DIR / f"shogunify-{CURRENT_VERSION}.apk"
    if not apk_path.exists():
        return jsonify({'error': 'APK not found'}), 404
    return send_file(apk_path, as_attachment=True, download_name=f"shogunify-{CURRENT_VERSION}.apk")

@app.route('/shogunify/download', methods=['GET'])
@app.route('/shogunify/download/', methods=['GET'])
def shogunify_download_page():
    html_path = BASE_DIR / "download.html"
    if not html_path.exists():
        return jsonify({'error': 'download page not found'}), 404
    return send_file(html_path)

@app.route('/Icon6.jpg', methods=['GET'])
@app.route('/shogunify/Icon6.jpg', methods=['GET'])
@app.route('/assets/images/Icon6.jpg', methods=['GET'])
@app.route('/shogunify/assets/images/Icon6.jpg', methods=['GET'])
def shogunify_icon():
    icon_path = BASE_DIR / "Icon6.jpg"
    if not icon_path.exists():
        return jsonify({'error': 'icon not found'}), 404
    return send_file(icon_path, mimetype='image/jpeg')

@app.route('/shogunify/download/apk', methods=['GET'])
@app.route('/shogunify/app-release.apk', methods=['GET'])
@app.route('/app-release.apk', methods=['GET'])
def download_apk_alias():
    return download_apk()

@app.post("/api/import/youtube/preview")
def import_youtube_preview():
    """Download one YouTube video to a temporary MP3 preview."""
    payload = request.get_json(silent=True) or {}
    url = (payload.get("url") or "").strip()
    if not url:
        return error_response("URL_REQUIRED", "A YouTube URL is required.", 400)

    try:
        import yt_dlp
    except ImportError:
        return error_response("YTDLP_MISSING", "Install yt-dlp on the server.", 503)

    token = secrets.token_urlsafe(24)
    output = PREVIEW_DIR / f"{token}.mp3"
    try:
        options = {
            "format": "bestaudio/best",
            "outtmpl": str(output),
            "noplaylist": True,
            "quiet": True,
            "no_warnings": True,
            "postprocessors": [{
                "key": "FFmpegExtractAudio",
                "preferredcodec": "mp3",
                "preferredquality": "192",
            }],
        }
        with yt_dlp.YoutubeDL(options) as downloader:
            info = downloader.extract_info(url, download=True)
        if not output.exists():
            candidates = list(PREVIEW_DIR.glob(f"{token}.*"))
            if candidates:
                shutil.move(str(candidates[0]), str(output))
        if not output.exists():
            raise RuntimeError("yt-dlp did not create an audio file.")

        PREVIEWS[token] = {
            "path": output,
            "title": (info.get("title") if isinstance(info, dict) else None) or "YouTube audio",
            "source_url": url,
            "video_id": info.get("id") if isinstance(info, dict) else None,
        }
        return jsonify({
            "preview_token": token,
            "source_title": PREVIEWS[token]["title"],
            "preview_url": f"/api/import/youtube/preview/{token}/audio",
        })
    except Exception as exc:
        output.unlink(missing_ok=True)
        return error_response("YOUTUBE_IMPORT_FAILED", str(exc), 502)


@app.get("/api/import/youtube/preview/<token>/audio")
def stream_youtube_preview(token: str):
    preview = PREVIEWS.get(token)
    if not preview or not preview["path"].exists():
        return error_response("PREVIEW_NOT_FOUND", "The preview was not found or expired.", 404)
    return send_file(preview["path"], mimetype="audio/mpeg", conditional=True)


@app.delete("/api/import/preview/<token>")
def delete_youtube_preview(token: str):
    preview = PREVIEWS.pop(token, None)
    if preview:
        preview["path"].unlink(missing_ok=True)
    return jsonify({"ok": True})


@app.route("/api/songs", methods=["POST"])
def create_song():
    """Create a song from multipart audio, metadata, and optional album art."""
    audio = request.files.get("audio")
    preview_token = (request.form.get("preview_token") or "").strip() or None
    preview = PREVIEWS.get(preview_token) if preview_token else None
    if preview_token and (preview is None or not preview["path"].exists()):
        return error_response("PREVIEW_NOT_FOUND", "The preview was not found or expired.", 404)

    title = (request.form.get("title") or "").strip()
    artist = (request.form.get("artist") or "").strip() or None
    source_url = (request.form.get("source_url") or "").strip() or (preview["source_url"] if preview else None)
    source_video_id = (request.form.get("source_video_id") or "").strip() or (preview["video_id"] if preview else None)
    source_type = (request.form.get("source_type") or "").strip() or ("youtube" if preview else None)
    user_id_text = (request.form.get("user_id") or "").strip()
    duration_text = (request.form.get("duration") or "").strip()

    if preview is None and (audio is None or not audio.filename):
        return error_response("AUDIO_REQUIRED", "The audio MP3 file or preview_token is required.", 400)
    if not title:
        return error_response("TITLE_REQUIRED", "The song title is required.", 400)
    if preview is None and Path(audio.filename).suffix.lower() not in ALLOWED_AUDIO_EXTENSIONS:
        return error_response("INVALID_AUDIO", "Only MP3 audio files are supported.", 400)

    try:
        duration = int(duration_text) if duration_text else None
        if duration is not None and duration < 0:
            raise ValueError
    except ValueError:
        return error_response("INVALID_DURATION", "Duration must be a non-negative integer.", 400)

    try:
        user_id = int(user_id_text) if user_id_text else 1
    except ValueError:
        return error_response("INVALID_USER", "user_id must be an integer.", 400)

    audio_part = None
    art_part = None
    final_audio = MUSIC_DIR / f"song_{secrets.token_hex(16)}.mp3"
    try:
        audio_bytes = (
            preview["path"].read_bytes()
            if preview is not None
            else audio.read(app.config["MAX_CONTENT_LENGTH"] + 1)
        )
        if len(audio_bytes) > app.config["MAX_CONTENT_LENGTH"]:
            return error_response("UPLOAD_TOO_LARGE", "The upload exceeds the 256 MB limit.", 413)
        if not audio_bytes:
            return error_response("INVALID_AUDIO", "The audio file is empty.", 400)
        audio_part = save_part(audio_bytes, MUSIC_DIR, ".mp3")
        file_hash = hashlib.sha256(audio_bytes).hexdigest()
        file_size = len(audio_bytes)

        processed_art = process_album_art(request.files.get("album_art"))
        if processed_art:
            jpeg_bytes, art_hash, art_filename = processed_art
            art_part = save_part(jpeg_bytes, ALBUM_ART_DIR, ".jpg")
        else:
            art_hash = art_filename = None

        conn = get_db()
        try:
            conn.execute("BEGIN")
            user = conn.execute(
                "SELECT id FROM users WHERE id=? AND is_active=1", (user_id,)
            ).fetchone()
            if user is None:
                return error_response("USER_NOT_FOUND", "The selected user does not exist.", 400)

            album_art_id = None
            if processed_art:
                existing = conn.execute(
                    "SELECT id FROM album_art WHERE hash=?", (art_hash,)
                ).fetchone()
                if existing:
                    album_art_id = existing["id"]
                    art_part.unlink(missing_ok=True)
                    art_part = None
                else:
                    os.replace(art_part, ALBUM_ART_DIR / art_filename)
                    art_part = None
                    conn.execute(
                        "INSERT INTO album_art(hash, filename) VALUES (?, ?)",
                        (art_hash, art_filename),
                    )
                    album_art_id = conn.execute("SELECT last_insert_rowid()").fetchone()[0]

            os.replace(audio_part, final_audio)
            audio_part = None
            cursor = conn.execute(
                """
                INSERT INTO songs(
                    title, artist, filename, album_art_id, duration,
                    source_type, source_video_id, source_url,
                    file_size, file_hash, mime_type, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'audio/mpeg', CURRENT_TIMESTAMP)
                """,
                (
                    title, artist, final_audio.name, album_art_id, duration,
                    source_type, source_video_id, source_url,
                    file_size, file_hash,
                ),
            )
            song_id = cursor.lastrowid
            conn.execute(
                "INSERT INTO user_songs(user_id, song_id, role) VALUES (?, ?, 'owner')",
                (user_id, song_id),
            )
            conn.commit()
            row = conn.execute(
                song_query() + " WHERE songs.id=?", (song_id,)
            ).fetchone()
            if preview_token:
                PREVIEWS.pop(preview_token, None)
                preview["path"].unlink(missing_ok=True)
            return jsonify(serialize_song(row)), 201
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
    except ValueError as exc:
        return error_response("INVALID_ALBUM_ART", str(exc), 400)
    except sqlite3.IntegrityError as exc:
        return error_response("DATABASE_ERROR", "The song could not be saved.", 409)
    except Exception:
        return error_response("UPLOAD_FAILED", "The song upload could not be completed.", 500)
    finally:
        if audio_part:
            audio_part.unlink(missing_ok=True)
        if art_part:
            art_part.unlink(missing_ok=True)


@app.route("/api/songs/<int:song_id>", methods=["POST"])
def update_song(song_id):
    conn = get_db()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT id FROM songs WHERE id = ?", (song_id,))
        if cursor.fetchone() is None:
            return jsonify({"error": "Song not found"}), 404

        title = request.form.get("title")
        artist = request.form.get("artist")
        if title and title.strip():
            cursor.execute("UPDATE songs SET title = ?, updated_at=CURRENT_TIMESTAMP WHERE id = ?", (title.strip(), song_id))
        if artist is not None:
            cursor.execute("UPDATE songs SET artist = ?, updated_at=CURRENT_TIMESTAMP WHERE id = ?", (artist.strip() or None, song_id))

        if "album_art" in request.files and request.files["album_art"].filename:
            processed = process_album_art(request.files["album_art"])
            jpeg_bytes, file_hash, art_filename = processed
            existing = cursor.execute("SELECT id FROM album_art WHERE hash = ?", (file_hash,)).fetchone()
            if existing:
                album_art_id = existing["id"]
            else:
                (ALBUM_ART_DIR / art_filename).write_bytes(jpeg_bytes)
                cursor.execute("INSERT INTO album_art(hash, filename) VALUES (?, ?)", (file_hash, art_filename))
                album_art_id = cursor.lastrowid
            cursor.execute("UPDATE songs SET album_art_id = ?, updated_at=CURRENT_TIMESTAMP WHERE id = ?", (album_art_id, song_id))

        conn.commit()
        row = conn.execute(song_query() + " WHERE songs.id=?", (song_id,)).fetchone()
        return jsonify(serialize_song(row))
    except ValueError as exc:
        conn.rollback()
        return error_response("INVALID_ALBUM_ART", str(exc), 400)
    finally:
        conn.close()


@app.route('/stream/<filename>', methods=['GET'])
def stream_song(filename):
    safe_filename = Path(filename).name
    file_path = MUSIC_DIR / safe_filename

    if not file_path.exists() or file_path.suffix.lower() != '.mp3':
        return jsonify({'error': 'File not found'}), 404

    response = send_file(file_path, mimetype='audio/mpeg')
    response.headers['Cache-Control'] = 'public, max-age=31536000, immutable'
    return response

@app.route("/api/playlists/favorites", methods=["GET"])
def get_favorites_playlist():
    conn = get_db()
    try:
        user_id = get_current_user_id(conn)
        playlist_id = get_or_create_favorites_playlist(conn, user_id)
        conn.commit()
        row = conn.execute(
            """
            SELECT p.*, a.filename AS cover_art_filename,
                   (SELECT COUNT(*) FROM playlist_songs WHERE playlist_id = p.id) AS song_count
            FROM playlists p
            LEFT JOIN album_art a ON p.cover_art_id = a.id
            WHERE p.id = ?
            """,
            (playlist_id,),
        ).fetchone()
        return jsonify(serialize_playlist(row))
    finally:
        conn.close()

@app.route('/album_art/<filename>', methods=['GET'])
def get_album_art(filename):
    safe_filename = Path(filename).name
    file_path = ALBUM_ART_DIR / safe_filename

    if not file_path.exists():
        return jsonify({'error': 'Image not found'}), 404

    response = send_file(file_path, mimetype='image/jpeg')
    response.headers['Cache-Control'] = 'public, max-age=31536000, immutable'
    return response

@app.route("/api/auth/login", methods=["POST"])
def auth_login():
    """Sign up a new user or reclaim an existing username. Same endpoint for both."""
    payload = request.get_json(silent=True) or {}
    username = (payload.get("username") or "").strip()
    invite_code = (payload.get("invite_code") or "").strip()

    if not username:
        return error_response("USERNAME_REQUIRED", "Username is required.", 400)
    if invite_code != INVITE_CODE:
        return error_response("INVALID_INVITE_CODE", "Invalid invite code.", 401)

    token = secrets.token_urlsafe(32)
    conn = get_db()
    try:
        existing = conn.execute(
            "SELECT id FROM users WHERE username=?", (username,)
        ).fetchone()
        if existing:
            conn.execute(
                "UPDATE users SET token=?, is_active=1 WHERE id=?",
                (token, existing["id"]),
            )
            user_id = existing["id"]
        else:
            cursor = conn.execute(
                "INSERT INTO users(username, display_name, token) VALUES (?, ?, ?)",
                (username, username, token),
            )
            user_id = cursor.lastrowid
            get_or_create_favorites_playlist(conn, user_id)
        conn.commit()
        return jsonify({"user_id": user_id, "username": username, "token": token})
    finally:
        conn.close()

def serialize_playlist(row: sqlite3.Row) -> dict:
    return {
        "id": row["id"],
        "user_id": row["user_id"],
        "name": row["name"],
        "description": row["description"],
        "cover_art_url": (
            f"/album_art/{row['cover_art_filename']}"
            if row["cover_art_filename"]
            else None
        ),
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
        "song_count": row["song_count"] if "song_count" in row.keys() else 0,
    }


def get_current_user_id(conn: sqlite3.Connection) -> int:
    auth_header = request.headers.get("Authorization", "")
    token = auth_header.removeprefix("Bearer ").strip()
    if token:
        row = conn.execute(
            "SELECT id FROM users WHERE token=? AND is_active=1", (token,)
        ).fetchone()
        if row:
            return row["id"]
    return request.args.get("user_id", type=int) or 1


def get_or_create_favorites_playlist(conn: sqlite3.Connection, user_id: int) -> int:
    row = conn.execute(
        "SELECT id FROM playlists WHERE user_id = ? AND name = 'Favorites'",
        (user_id,),
    ).fetchone()
    if row:
        return row["id"]
    cursor = conn.execute(
        """
        INSERT INTO playlists (user_id, name, description, updated_at)
        VALUES (?, 'Favorites', 'Your favorite songs', CURRENT_TIMESTAMP)
        """,
        (user_id,),
    )
    return cursor.lastrowid

# 1. Fetch all playlists for a user
@app.route("/api/playlists", methods=["GET"])
def list_playlists():
    conn = get_db()
    try:
        user_id = get_current_user_id(conn)
        query = """
            SELECT p.id, p.user_id, p.name, p.description, p.created_at, p.updated_at,
                   a.filename AS cover_art_filename,
                   COUNT(ps.song_id) AS song_count
            FROM playlists p
            LEFT JOIN album_art a ON p.cover_art_id = a.id
            LEFT JOIN playlist_songs ps ON p.id = ps.playlist_id
            WHERE p.user_id = ?
            GROUP BY p.id
            ORDER BY p.id DESC
        """
        rows = conn.execute(query, (user_id,)).fetchall()
        playlists = []
        for row in rows:
            playlist = serialize_playlist(row)
            # Fetch just the first 4 songs' album art for the mosaic cover
            art_rows = conn.execute(
                """
                SELECT s.album_art_id, aa.filename AS art_filename
                FROM playlist_songs ps
                JOIN songs s ON ps.song_id = s.id
                LEFT JOIN album_art aa ON s.album_art_id = aa.id
                WHERE ps.playlist_id = ?
                ORDER BY ps.position
                LIMIT 4
                """,
                (row["id"],),
            ).fetchall()
            playlist["songs"] = [
                {"album_art_url": f"/album_art/{r['art_filename']}" if r["art_filename"] else None}
                for r in art_rows
            ]
            playlists.append(playlist)
        return jsonify(playlists)
    finally:
        conn.close()

# 2. Create a new playlist
@app.route("/api/playlists", methods=["POST"])
def create_playlist():
    payload = request.get_json(silent=True) or {}
    name = (payload.get("name") or "").strip()
    description = (payload.get("description") or "").strip() or None

    if not name:
        return error_response("NAME_REQUIRED", "Playlist name is required.", 400)

    conn = get_db()
    try:
        user_id = payload.get("user_id")
        if not user_id:
            user_id = get_current_user_id(conn)
        cursor = conn.execute(
            """
            INSERT INTO playlists (user_id, name, description, updated_at)
            VALUES (?, ?, ?, CURRENT_TIMESTAMP)
            """,
            (user_id, name, description),
        )
        conn.commit()
        playlist_id = cursor.lastrowid

        row = conn.execute(
            """
            SELECT p.*, a.filename AS cover_art_filename, 0 AS song_count
            FROM playlists p
            LEFT JOIN album_art a ON p.cover_art_id = a.id
            WHERE p.id = ?
            """,
            (playlist_id,),
        ).fetchone()
        return jsonify(serialize_playlist(row)), 201
    finally:
        conn.close()


# 3. Get playlist details along with its ordered songs
@app.route("/api/playlists/<int:playlist_id>", methods=["GET"])
def get_playlist(playlist_id: int):
    conn = get_db()
    try:
        playlist = conn.execute(
            """
            SELECT p.*, a.filename AS cover_art_filename
            FROM playlists p
            LEFT JOIN album_art a ON p.cover_art_id = a.id
            WHERE p.id = ?
            """,
            (playlist_id,),
        ).fetchone()

        if not playlist:
            return error_response("NOT_FOUND", "Playlist not found.", 404)

        # Get songs ordered by position
        songs_query = song_query() + """
            JOIN playlist_songs ps ON songs.id = ps.song_id
            WHERE ps.playlist_id = ? AND songs.is_deleted = 0
            ORDER BY ps.position ASC
        """
        song_rows = conn.execute(songs_query, (playlist_id,)).fetchall()

        result = serialize_playlist(playlist)
        result["songs"] = [serialize_song(row) for row in song_rows]
        return jsonify(result)
    finally:
        conn.close()


# 4. Add a song to a playlist
@app.route("/api/playlists/<int:playlist_id>/songs", methods=["POST"])
def add_song_to_playlist(playlist_id: int):
    payload = request.get_json(silent=True) or {}
    song_id = payload.get("song_id")

    if not song_id:
        return error_response("SONG_ID_REQUIRED", "song_id is required.", 400)

    conn = get_db()
    try:
        # Determine next position index
        pos_row = conn.execute(
            "SELECT COALESCE(MAX(position), -1) + 1 AS next_pos FROM playlist_songs WHERE playlist_id = ?",
            (playlist_id,),
        ).fetchone()
        next_pos = pos_row["next_pos"]

        conn.execute(
            """
            INSERT INTO playlist_songs (playlist_id, song_id, position)
            VALUES (?, ?, ?)
            """,
            (playlist_id, song_id, next_pos),
        )
        conn.execute(
            "UPDATE playlists SET updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            (playlist_id,),
        )
        conn.commit()
        return jsonify({"ok": True, "playlist_id": playlist_id, "song_id": song_id, "position": next_pos}), 201
    except sqlite3.IntegrityError:
        return error_response("ALREADY_EXISTS", "Song is already in this playlist.", 409)
    finally:
        conn.close()


# 5. Remove a song from a playlist
@app.route("/api/playlists/<int:playlist_id>/songs/<int:song_id>", methods=["DELETE"])
def remove_song_from_playlist(playlist_id: int, song_id: int):
    conn = get_db()
    try:
        conn.execute(
            "DELETE FROM playlist_songs WHERE playlist_id = ? AND song_id = ?",
            (playlist_id, song_id),
        )
        conn.execute(
            "UPDATE playlists SET updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            (playlist_id,),
        )
        conn.commit()
        return jsonify({"ok": True})
    finally:
        conn.close()


# 6. Delete a playlist
@app.route("/api/playlists/<int:playlist_id>", methods=["DELETE"])
def delete_playlist(playlist_id: int):
    conn = get_db()
    try:
        user_id = get_current_user_id(conn)
        conn.execute("DELETE FROM playlists WHERE id = ? AND user_id = ?", (playlist_id, user_id))
        conn.commit()
        return jsonify({"ok": True})
    finally:
        conn.close()

@app.route("/api/auth/verify", methods=["GET"])
def auth_verify():
    auth_header = request.headers.get("Authorization", "")
    token = auth_header.removeprefix("Bearer ").strip()
    if not token:
        return error_response("TOKEN_REQUIRED", "No token provided.", 401)

    conn = get_db()
    try:
        row = conn.execute(
            "SELECT id, username FROM users WHERE token=? AND is_active=1", (token,)
        ).fetchone()
        if row is None:
            return error_response("INVALID_TOKEN", "Token is invalid or expired.", 401)
        return jsonify({"user_id": row["id"], "username": row["username"]})
    finally:
        conn.close()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8091, debug=False)
