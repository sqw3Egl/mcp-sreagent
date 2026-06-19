"""GitHub App-backed read-only file fetch tool.

Expected environment variables:
- GITHUB_APP_ID: GitHub App ID.
- GITHUB_APP_PRIVATE_KEY_PEM or GITHUB_APP_PRIVATE_KEY_B64: PEM private key.
- GITHUB_INSTALLATION_MODE: "auto" or "fixed". Defaults to "auto".
- GITHUB_INSTALLATION_ID: required when installation mode is "fixed".
- ALLOWED_ORGS: comma-separated org allowlist. Required for safe use.
- ALLOWED_REPOS: optional comma-separated repo allowlist. Accepts either repo or org/repo.
- ALLOWED_PATH_PREFIXES: optional comma-separated safe path prefixes.
- MAX_FILE_BYTES: optional default per-call cap, default 262144.
- BLOCK_BINARY_FILES: optional, default true.
- REDACT_SECRETS_IN_ERRORS: optional, default true.

Expected call parameters:
- org (required)
- repo (required)
- path (required)
- ref (optional)
- maxBytes (optional)
- failOnTruncate (optional, default false)
- includeMetadata (optional, default true)
"""

import base64
import json
import mimetypes
import os
import posixpath
import time
import urllib.error
import urllib.parse
import urllib.request


MAX_HARD_LIMIT = 1024 * 1024
DEFAULT_MAX_FILE_BYTES = int(os.getenv("MAX_FILE_BYTES", "262144"))
BLOCK_BINARY_FILES = os.getenv("BLOCK_BINARY_FILES", "true").lower() == "true"
REDACT_SECRETS_IN_ERRORS = os.getenv("REDACT_SECRETS_IN_ERRORS", "true").lower() == "true"
INSTALLATION_MODE = os.getenv("GITHUB_INSTALLATION_MODE", "auto").strip().lower() or "auto"
FIXED_INSTALLATION_ID = os.getenv("GITHUB_INSTALLATION_ID", "").strip()
GITHUB_APP_ID = os.getenv("GITHUB_APP_ID", "").strip()

ALLOWED_ORGS = {x.strip() for x in os.getenv("ALLOWED_ORGS", "").split(",") if x.strip()}
ALLOWED_REPOS = {x.strip() for x in os.getenv("ALLOWED_REPOS", "").split(",") if x.strip()}
ALLOWED_PATH_PREFIXES = [x.strip() for x in os.getenv("ALLOWED_PATH_PREFIXES", "").split(",") if x.strip()]


class ToolError(Exception):
    def __init__(self, code, message, retryable=False):
        super().__init__(message)
        self.code = code
        self.message = message
        self.retryable = retryable


def _result_error(code, message, retryable=False):
    if REDACT_SECRETS_IN_ERRORS:
        for key in [
            "GITHUB_APP_PRIVATE_KEY_PEM",
            "GITHUB_APP_PRIVATE_KEY_B64",
            "GITHUB_APP_ID",
            "GITHUB_INSTALLATION_ID",
        ]:
            secret_value = os.getenv(key, "")
            if secret_value:
                message = message.replace(secret_value, "<redacted>")
    return {"code": code, "message": message, "retryable": retryable}


def _b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _load_private_key_pem():
    pem = os.getenv("GITHUB_APP_PRIVATE_KEY_PEM", "").strip()
    if pem:
        return pem.replace("\\n", "\n")

    pem_b64 = os.getenv("GITHUB_APP_PRIVATE_KEY_B64", "").strip()
    if pem_b64:
        try:
            return base64.b64decode(pem_b64.encode("ascii")).decode("utf-8")
        except Exception as exc:
            raise ToolError("access_denied", f"Failed to decode GITHUB_APP_PRIVATE_KEY_B64: {exc}")

    raise ToolError("access_denied", "GitHub App private key is not configured")


def _build_app_jwt():
    if not GITHUB_APP_ID:
        raise ToolError("access_denied", "GITHUB_APP_ID is not configured")

    private_key_pem = _load_private_key_pem()
    now = int(time.time())
    payload = {"iat": now - 60, "exp": now + 540, "iss": GITHUB_APP_ID}

    try:
        import jwt  # type: ignore

        token = jwt.encode(payload, private_key_pem, algorithm="RS256")
        return token.decode("utf-8") if isinstance(token, bytes) else token
    except Exception:
        pass

    try:
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import padding

        header = {"alg": "RS256", "typ": "JWT"}
        signing_input = (
            f"{_b64url(json.dumps(header, separators=(',', ':')).encode('utf-8'))}."
            f"{_b64url(json.dumps(payload, separators=(',', ':')).encode('utf-8'))}"
        ).encode("ascii")
        private_key = serialization.load_pem_private_key(private_key_pem.encode("utf-8"), password=None)
        signature = private_key.sign(signing_input, padding.PKCS1v15(), hashes.SHA256())
        return f"{signing_input.decode('ascii')}.{_b64url(signature)}"
    except Exception as exc:
        raise ToolError(
            "internal_error",
            "GitHub App JWT signing requires PyJWT or cryptography in the Python runtime: " + str(exc),
        )


def _normalize_path(path):
    if not isinstance(path, str) or not path.strip():
        raise ToolError("path_not_allowed", "path must be a non-empty string")

    normalized = posixpath.normpath("/" + path.lstrip("/")).lstrip("/")
    if normalized in ("", ".", "..") or normalized.startswith("../") or "/../" in normalized:
        raise ToolError("path_not_allowed", "path must resolve to a repository-relative file path")
    return normalized


def _is_allowed_org(org):
    return bool(ALLOWED_ORGS) and org in ALLOWED_ORGS


def _is_allowed_repo(org, repo):
    if not ALLOWED_REPOS:
        return True
    return f"{org}/{repo}" in ALLOWED_REPOS or repo in ALLOWED_REPOS


def _is_allowed_path(path):
    if not ALLOWED_PATH_PREFIXES:
        return True
    normalized_prefixes = [prefix.rstrip("/") for prefix in ALLOWED_PATH_PREFIXES if prefix.strip()]
    return any(path == prefix or path.startswith(prefix + "/") for prefix in normalized_prefixes)


def _guess_content_type(path):
    content_type, _ = mimetypes.guess_type(path)
    return content_type or "text/plain"


def _looks_binary(raw_bytes):
    if not raw_bytes:
        return False
    if b"\x00" in raw_bytes:
        return True
    sample = raw_bytes[:1024]
    non_text = sum(1 for b in sample if b < 9 or (13 < b < 32))
    return non_text > max(8, len(sample) // 10)


def _http_json(method, url, headers, body=None):
    request_body = None
    if body is not None:
        request_body = json.dumps(body).encode("utf-8")
        headers = dict(headers)
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url, data=request_body, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            payload = json.loads(raw.decode("utf-8")) if raw else {}
            return resp.status, payload, dict(resp.headers)
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        payload = {}
        if raw:
            try:
                payload = json.loads(raw.decode("utf-8"))
            except Exception:
                payload = {"message": raw.decode("utf-8", errors="replace")}
        return exc.code, payload, dict(exc.headers)
    except urllib.error.URLError as exc:
        raise ToolError("internal_error", f"Network error calling GitHub: {exc}", retryable=True)


def _app_headers():
    return {
        "Authorization": f"Bearer {_build_app_jwt()}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "azure-sre-agent-custom-tool/github_app_read_file",
        "X-GitHub-Api-Version": "2022-11-28",
    }


def _installation_headers(token):
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "azure-sre-agent-custom-tool/github_app_read_file",
        "X-GitHub-Api-Version": "2022-11-28",
    }


def _resolve_installation_id(org, repo):
    if INSTALLATION_MODE == "fixed":
        if not FIXED_INSTALLATION_ID:
            raise ToolError("installation_not_found", "GITHUB_INSTALLATION_ID is required when GITHUB_INSTALLATION_MODE=fixed")
        return FIXED_INSTALLATION_ID

    if INSTALLATION_MODE != "auto":
        raise ToolError("installation_not_found", f"Unsupported GITHUB_INSTALLATION_MODE: {INSTALLATION_MODE}")

    repo_url = f"https://api.github.com/repos/{urllib.parse.quote(org)}/{urllib.parse.quote(repo)}/installation"
    status, payload, _ = _http_json("GET", repo_url, _app_headers())
    if status == 200 and payload.get("id"):
        return str(payload["id"])

    org_url = f"https://api.github.com/orgs/{urllib.parse.quote(org)}/installation"
    status, payload, _ = _http_json("GET", org_url, _app_headers())
    if status == 200 and payload.get("id"):
        return str(payload["id"])

    if status in (401, 403):
        raise ToolError("access_denied", payload.get("message", "Access denied while resolving GitHub App installation"))
    raise ToolError("installation_not_found", f"No GitHub App installation found for {org}/{repo}")


def _create_installation_token(org, repo):
    installation_id = _resolve_installation_id(org, repo)
    url = f"https://api.github.com/app/installations/{urllib.parse.quote(installation_id)}/access_tokens"
    status, payload, _ = _http_json("POST", url, _app_headers(), body={"repositories": [repo]})

    if status in (200, 201) and payload.get("token"):
        return payload["token"]
    if status == 404:
        raise ToolError("installation_not_found", payload.get("message", "GitHub App installation not found"))
    if status in (401, 403):
        raise ToolError("access_denied", payload.get("message", "Access denied creating installation token"))
    raise ToolError("internal_error", payload.get("message", "Failed to create installation token"), retryable=status >= 500)


def _get_repo_metadata(org, repo, token):
    url = f"https://api.github.com/repos/{urllib.parse.quote(org)}/{urllib.parse.quote(repo)}"
    status, payload, _ = _http_json("GET", url, _installation_headers(token))

    if status == 404:
        raise ToolError("repo_not_allowed", f"Repository '{org}/{repo}' was not found or is not accessible")
    if status in (401, 403):
        raise ToolError("access_denied", payload.get("message", "Access denied to repository metadata"))
    if status >= 500:
        raise ToolError("internal_error", "GitHub repository metadata request failed", retryable=True)
    return payload


def _get_commit_sha(org, repo, ref, token):
    url = f"https://api.github.com/repos/{urllib.parse.quote(org)}/{urllib.parse.quote(repo)}/commits/{urllib.parse.quote(ref, safe='')}"
    status, payload, _ = _http_json("GET", url, _installation_headers(token))

    if status == 404:
        raise ToolError("ref_not_found", f"Ref '{ref}' was not found")
    if status in (401, 403):
        raise ToolError("access_denied", payload.get("message", "Access denied to commit metadata"))
    if status >= 500:
        raise ToolError("internal_error", "GitHub commit lookup failed", retryable=True)

    sha = payload.get("sha")
    if not sha:
        raise ToolError("internal_error", "Commit SHA missing from GitHub response")
    return sha


def _get_file(org, repo, path, ref, token):
    encoded_path = "/".join(urllib.parse.quote(part, safe="") for part in path.split("/"))
    url = (
        f"https://api.github.com/repos/{urllib.parse.quote(org)}/{urllib.parse.quote(repo)}"
        f"/contents/{encoded_path}?ref={urllib.parse.quote(ref, safe='')}"
    )
    status, payload, headers = _http_json("GET", url, _installation_headers(token))

    if status == 404:
        raise ToolError("not_found", f"File '{path}' was not found")
    if status in (401, 403):
        raise ToolError("access_denied", payload.get("message", "Access denied to file"))
    if status >= 500:
        raise ToolError("internal_error", "GitHub file request failed", retryable=True)

    if isinstance(payload, list):
        raise ToolError("not_found", "The requested path is a directory, not a file")
    if payload.get("type") != "file":
        raise ToolError("not_found", "The requested path is not a file")
    if payload.get("encoding") != "base64":
        raise ToolError("internal_error", f"Unsupported GitHub content encoding: {payload.get('encoding')}")

    content = payload.get("content", "")
    raw_bytes = base64.b64decode(content.encode("utf-8"))
    return {
        "sizeBytes": int(payload.get("size", 0)),
        "rawBytes": raw_bytes,
        "contentType": _guess_content_type(path),
        "etag": headers.get("ETag"),
    }


def main(params):
    try:
        org = params["org"]
        repo = params["repo"]
        path = _normalize_path(params["path"])
        ref = params.get("ref")
        max_bytes = int(params.get("maxBytes", DEFAULT_MAX_FILE_BYTES))
        fail_on_truncate = bool(params.get("failOnTruncate", False))
        include_metadata = bool(params.get("includeMetadata", True))

        if not ALLOWED_ORGS:
            raise ToolError("org_not_allowed", "ALLOWED_ORGS must be configured")
        if not _is_allowed_org(org):
            raise ToolError("org_not_allowed", f"Organization '{org}' is not allowed")
        if not _is_allowed_repo(org, repo):
            raise ToolError("repo_not_allowed", f"Repository '{org}/{repo}' is not allowed")
        if not _is_allowed_path(path):
            raise ToolError("path_not_allowed", f"Path '{path}' is not allowed")
        if max_bytes < 1 or max_bytes > MAX_HARD_LIMIT:
            raise ToolError("file_too_large", f"maxBytes must be between 1 and {MAX_HARD_LIMIT}")

        installation_token = _create_installation_token(org, repo)
        repo_metadata = _get_repo_metadata(org, repo, installation_token)
        resolved_ref = ref or repo_metadata.get("default_branch")
        if not resolved_ref:
            raise ToolError("internal_error", "Repository default branch is missing")

        commit_sha = _get_commit_sha(org, repo, resolved_ref, installation_token)
        file_info = _get_file(org, repo, path, resolved_ref, installation_token)
        raw_bytes = file_info["rawBytes"]

        if BLOCK_BINARY_FILES and _looks_binary(raw_bytes):
            raise ToolError("binary_file_not_supported", "Binary files are not supported by this tool")

        try:
            decoded = raw_bytes.decode("utf-8")
            encoding = "utf-8"
        except UnicodeDecodeError:
            raise ToolError("binary_file_not_supported", "File content is not valid utf-8 text")

        warnings = []
        truncated = False
        if len(raw_bytes) > max_bytes:
            if fail_on_truncate:
                raise ToolError("file_too_large", f"File exceeds maxBytes limit of {max_bytes}")
            decoded = raw_bytes[:max_bytes].decode("utf-8", errors="ignore")
            truncated = True
            warnings.append(f"Content truncated to {max_bytes} bytes")

        result = {
            "org": org,
            "repo": repo,
            "path": path,
            "ref": resolved_ref,
            "content": decoded,
            "truncated": truncated,
        }

        if include_metadata:
            result["commitSha"] = commit_sha
            result["sizeBytes"] = file_info["sizeBytes"]
            result["contentType"] = file_info["contentType"]
            result["encoding"] = encoding
            if warnings:
                result["warnings"] = warnings

        return result
    except ToolError as exc:
        return _result_error(exc.code, exc.message, exc.retryable)
    except KeyError as exc:
        return _result_error("internal_error", f"Missing required input: {exc.args[0]}")
    except Exception as exc:
        return _result_error("internal_error", f"Unexpected error: {exc}")
